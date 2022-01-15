`include "../defines.svh"

// if/mem stage requests
// baseram/extram/uart control signals
// 2x3 crossbar
module bus (
    input clk, rst,

    // CPU IF signals
    input word_t if_address,
    input bit_t if_load,
    input bit_t trap_flag,
    input word_t trap_target,
    output word_t if_rdata,
    output bit_t if_stall_req,
    // CPU MEM signals
    input word_t mem_address,
    input bit_t mem_load,
    input bit_t mem_store,
    input logic[3:0] mem_byte_en,
    input word_t mem_wdata,
    output word_t mem_rdata,
    output bit_t mem_stall_req,
    // CPU timer interrupt signals
    output bit_t time_int,
    output bit_t clear_mip,

    // UART controller signals
    output logic uart_load,
    output logic uart_store,
    output word_t uart_wdata,
    input word_t uart_rdata,
    input logic uart_busy,
    input logic uart_tbre,
    input logic uart_tsre,
    input logic uart_dataready,
    // BASERAM controller signals
    output logic baseram_load,
    output logic baseram_store,
    output word_t baseram_addr,
    output word_t baseram_wdata,
    output logic[3:0] baseram_byte_en,
    input word_t baseram_rdata,
    input logic baseram_busy,
    // EXTRAM controller signals
    output logic extram_load,
    output logic extram_store,
    output word_t extram_addr,
    output word_t extram_wdata,
    output logic[3:0] extram_byte_en,
    input word_t extram_rdata,
    input logic extram_busy
);

typedef enum logic[4:0] { 
    IDLE,
    WAITING,
    
    READ_UART_DATA,
    WRITE_UART_DATA,
    READ_UART_STATE,
    READ_UART_UNUSED_STATE,
    FLUSH_READING,
    
    READ_BASERAM,
    WRITE_BASERAM,

    READ_EXTRAM,
    WRITE_EXTRAM,

    READ_MTIME_LOW,
    READ_MTIME_HIGH,
    WRITE_MTIME_LOW,
    WRITE_MTIME_HIGH,

    READ_MTIMECMP_LOW,
    READ_MTIMECMP_HIGH,
    WRITE_MTIMECMP_LOW,
    WRITE_MTIMECMP_HIGH,

    FINISH
} bus_state_t;

// timer
word_t mtime_low, mtime_high;
word_t mtimecmp_low, mtimecmp_high;
bit_t mtime_low_load, mtime_low_store, mtime_high_load, mtime_high_store;
bit_t mtimecmp_low_load, mtimecmp_low_store, mtimecmp_high_load, mtimecmp_high_store;
always_ff @(posedge clk) begin
    if (rst) begin
        {mtime_high, mtime_low} <= 64'b0;
    end else begin
        {mtime_high, mtime_low} <= {mtime_high, mtime_low} + 64'b1;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        {mtimecmp_high, mtimecmp_low} <= 64'hffff_ffff_ffff_ffff;
    end else if (mtimecmp_low_store) begin
        mtimecmp_low <= mem_wdata;
    end else if (mtimecmp_high_store) begin
        mtimecmp_high <= mem_wdata;
    end    
end

assign time_int = {mtime_high, mtime_low} >= {mtimecmp_high, mtimecmp_low};
assign clear_mip = (mtimecmp_low_store | mtimecmp_high_store);

word_t inst_addr, data_addr;
bus_state_t inst_state_now, inst_state_nxt;
bus_state_t data_state_now, data_state_nxt;

// 外设驱动信号
logic uart_inst_load, uart_data_load;
logic baseram_inst_load, baseram_data_load;
logic extram_inst_load, extram_data_load;
logic uartstate_inst_load, uartstate_data_load;
logic uart_unused_inst_load, uart_unused_data_load;
assign uart_wdata = mem_wdata;
assign baseram_wdata = mem_wdata;
assign extram_wdata = mem_wdata;
assign baseram_byte_en = (baseram_data_load | baseram_store) ? mem_byte_en : 4'b1111;
assign extram_byte_en = (extram_data_load | extram_store) ? mem_byte_en : 4'b1111;
assign uart_load = (uart_inst_load | uart_data_load);
assign baseram_load = (baseram_inst_load | baseram_data_load);
assign extram_load = (extram_inst_load | extram_data_load);
assign baseram_addr = (baseram_data_load | baseram_store) ? data_addr : inst_addr;
assign extram_addr = (extram_data_load | extram_store) ? data_addr : inst_addr;
// 给CPU侧的数据
always_ff @(posedge clk) begin
    if (rst) begin
        if_rdata <= '0;
    end else if (inst_state_nxt == FINISH) begin
        // if (baseram_inst_load) begin
        //     if_rdata <= baseram_rdata;
        // end else if (extram_inst_load) begin
        //     if_rdata <= extram_rdata;
        // end else if (uart_inst_load) begin
        //     if_rdata <= uart_rdata;
        // end else if (uartstate_inst_load) begin
        //     if_rdata <= {18'h0, uart_tbre&uart_tsre, 4'b0000, uart_dataready, 8'b0};
        // end else if (uart_unused_inst_load) begin 
        //     if_rdata <= '0;
        // end else begin
        //     if_rdata <= if_rdata;
        // end

        if (baseram_inst_load) begin
            if_rdata <= baseram_rdata;
        end else if (extram_inst_load) begin
            if_rdata <= extram_rdata;
        end else if (uart_inst_load) begin
            if_rdata <= uart_rdata;
        end else begin
            if_rdata <= if_rdata;
        end
    end

    if (rst) begin
        mem_rdata <= '0;
    end else if (data_state_nxt == FINISH) begin
        if (baseram_data_load) begin
            mem_rdata <= baseram_rdata;
        end else if (extram_data_load) begin
            mem_rdata <= extram_rdata;
        end else if (uart_data_load) begin
            mem_rdata <= uart_rdata;
        end else if (uartstate_data_load) begin
            // 32'h1000_0005 不是4字节对齐的，可以左移8位接入CPU
            mem_rdata <= {18'h0, uart_tbre&uart_tsre, 4'b0000, uart_dataready, 8'b0};
        end else if (uart_unused_data_load) begin
            mem_rdata <= '0;
        end else if (mtime_low_load) begin
            mem_rdata <= mtime_low;
        end else if (mtime_high_load) begin
            mem_rdata <= mtime_high;
        end else if (mtimecmp_low_load) begin
            mem_rdata <= mtimecmp_low;
        end else if (mtimecmp_high_load) begin
            mem_rdata <= mtimecmp_high;
        end else begin
            mem_rdata <= mem_rdata;
        end
    end
end

// 控制冲突存在如下几种:
// 1. IF & MEM 流水段同时请求访�?
// 2. IF正在访存的时候，MEM发�?�访存请�?
// WARN: MEM访存的时候IF不会发�?�访存请求，因为MEM�?始访存的时�?�一定会暂停IF�?
// IF �? MEM 的访存过程都不需要CPU传�?�stall信号 ?
// 地址仲裁
function logic access_uart_data(input word_t addr);
    return (addr == 32'h1000_0000);
endfunction;
function logic access_uart_state(input word_t addr);
    return (addr == 32'h1000_0005);
endfunction;
function logic access_uart_unused_state(input word_t addr);
    return (addr > 32'h1000_0000 && addr < 32'h1000_0005) ||
           (addr > 32'h1000_0005 && addr <= 32'h1000_0008);
endfunction;
function logic access_baseram(input word_t addr);
    return (addr >= 32'h8000_0000) && (addr <= 32'h803F_FFFF);
endfunction;
function logic access_extram(input word_t addr);
    return (addr >= 32'h8040_0000) && (addr <= 32'h807F_FFFF);
endfunction;
function logic access_fault(input word_t addr);
    return (addr > 32'h1000_0008 && addr < 32'h8000_0000) ||
           (addr < 32'h1000_0000) || (addr > 32'h807F_FFFF);
endfunction;
function logic access_mtime_low(input word_t addr);
    return (addr == 32'h0200_bff8);
endfunction;
function logic access_mtime_high(input word_t addr);
    return (addr == 32'h0200_bff8 + 32'h4);
endfunction;
function logic access_mtimecmp_low(input word_t addr);
    return (addr == 32'h0200_4000);
endfunction;
function logic access_mtimecmp_high(input word_t addr);
    return (addr == 32'h0200_4000 + 32'h4);
endfunction;


assign if_stall_req = (inst_state_nxt != IDLE);
always_ff @(posedge clk) begin
    if (rst) begin
        inst_addr <= '0;
    end else if (trap_flag) begin
        inst_addr <= trap_target;
    end else if (if_load) begin
        inst_addr <= if_address;
    end

    if (rst) begin
        inst_state_now <= IDLE;
    end else begin
        inst_state_now <= inst_state_nxt;
    end
end
// inst bus FSM
always_comb begin: inst_fsm
    inst_state_nxt = inst_state_now;
    uart_inst_load = '0;
    baseram_inst_load = '0;
    extram_inst_load = '0;
    uartstate_inst_load = '0;
    uart_unused_inst_load = '0;
    unique case(inst_state_now)
    IDLE: begin
        inst_state_nxt = IDLE;
        if (if_load) inst_state_nxt = WAITING;
    end
    WAITING: begin
        if (trap_flag) begin
            inst_state_nxt = WAITING;
        end else if (~mem_stall_req) begin // wait for bus available
            // if (access_uart_data(inst_addr) && ~uart_busy && ~baseram_busy) begin
            //     inst_state_nxt = READ_UART_DATA;
            // end else if (access_uart_state(inst_addr)) begin
            //     inst_state_nxt = READ_UART_STATE;
            // end else if (access_uart_unused_state(inst_addr)) begin
            //     inst_state_nxt = READ_UART_UNUSED_STATE;
            // end else if (access_baseram(inst_addr) && ~uart_busy && ~baseram_busy) begin
            //     inst_state_nxt = READ_BASERAM;
            // end else if (access_extram(inst_addr) && ~extram_busy) begin
            //     inst_state_nxt = READ_EXTRAM;
            // end else begin
            //     inst_state_nxt = WAITING;
            // end

            if (access_baseram(inst_addr) && ~uart_busy && ~baseram_busy) begin
                inst_state_nxt = READ_BASERAM;
            end else if (access_extram(inst_addr) && ~extram_busy) begin
                inst_state_nxt = READ_EXTRAM;
            end else begin
                inst_state_nxt = WAITING;
            end
        end else begin
            inst_state_nxt = WAITING;
        end
    end
    READ_UART_DATA: begin
        uart_inst_load = 1'b1;
        if (trap_flag) inst_state_nxt = FLUSH_READING;
        else if (uart_busy) inst_state_nxt = READ_UART_DATA;
        else inst_state_nxt = FINISH;
    end
    READ_UART_STATE: begin
        uartstate_inst_load = 1'b1;
        if (trap_flag) inst_state_nxt = FLUSH_READING;
        else inst_state_nxt = FINISH;
    end
    READ_UART_UNUSED_STATE: begin
        uart_unused_inst_load = 1'b1;
        if (trap_flag) inst_state_nxt = FLUSH_READING;
        else inst_state_nxt = FINISH;
    end
    READ_BASERAM: begin
        baseram_inst_load = 1'b1;
        if (trap_flag) inst_state_nxt = FLUSH_READING;
        else if (baseram_busy) inst_state_nxt = READ_BASERAM;
        else inst_state_nxt = FINISH;
    end
    READ_EXTRAM: begin
        extram_inst_load = 1'b1;
        if (trap_flag) inst_state_nxt = FLUSH_READING;
        else if (extram_busy) inst_state_nxt = READ_EXTRAM;
        else inst_state_nxt = FINISH;
    end
    FLUSH_READING: begin
        inst_state_nxt = WAITING;
    end
    FINISH: begin
        inst_state_nxt = IDLE;
    end
    default: inst_state_nxt = IDLE;
    endcase   
end

// data bus FSM
assign mem_stall_req = (data_state_nxt != IDLE);
always_ff @(posedge clk) begin
    if (rst) begin
        data_addr <= '0;
    end else if (mem_load | mem_store) begin
        data_addr <= mem_address;
    end

    if (rst) begin
        data_state_now <= IDLE;
    end else begin
        data_state_now <= data_state_nxt;
    end
end
// data bus FSM
always_comb begin: data_fsm
    data_state_nxt = data_state_now;
    uart_data_load = '0;
    baseram_data_load = '0;
    extram_data_load = '0;
    uartstate_data_load = '0;
    uart_unused_data_load = '0;
    uart_store = '0;
    baseram_store = '0;
    extram_store = '0;
    mtime_low_load = '0;
    mtime_high_load = '0;
    mtimecmp_low_load = '0;
    mtimecmp_high_load = '0;
    mtime_low_store = '0;
    mtime_high_store = '0;
    mtimecmp_low_store = '0;
    mtimecmp_high_store = '0;
    unique case(data_state_now)
    IDLE: begin
        data_state_nxt = IDLE;
        if (mem_load | mem_store) data_state_nxt = WAITING;
    end
    WAITING: begin
        // wait for bus available
        if (mem_load) begin
            if (access_uart_data(data_addr) && ~uart_busy && ~baseram_busy) begin
                data_state_nxt = READ_UART_DATA;
            end else if (access_uart_state(data_addr)) begin
                data_state_nxt = READ_UART_STATE;
            end else if (access_uart_unused_state(data_addr)) begin
                data_state_nxt = READ_UART_UNUSED_STATE;
            end else if (access_baseram(data_addr) && ~uart_busy && ~baseram_busy) begin
                data_state_nxt = READ_BASERAM;
            end else if (access_extram(data_addr) && ~extram_busy) begin
                data_state_nxt = READ_EXTRAM;
            end else if (access_mtime_low(data_addr)) begin 
                data_state_nxt = READ_MTIME_LOW;
            end else if (access_mtime_high(data_addr)) begin 
                data_state_nxt = READ_MTIME_HIGH;
            end else if (access_mtimecmp_low(data_addr)) begin
                data_state_nxt = READ_MTIMECMP_LOW;
            end else if (access_mtimecmp_high(data_addr)) begin
                data_state_nxt = READ_MTIMECMP_HIGH;
            end else begin
                data_state_nxt = WAITING;
            end
        end else if (mem_store) begin
            if (access_uart_data(data_addr) && ~uart_busy && ~baseram_busy) begin
                data_state_nxt = WRITE_UART_DATA;
            end else if (access_uart_unused_state(data_addr)) begin
                data_state_nxt = IDLE; // do nothing
            end else if (access_baseram(data_addr) && ~uart_busy && ~baseram_busy) begin
                data_state_nxt = WRITE_BASERAM;
            end else if (access_extram(data_addr) && ~extram_busy) begin
                data_state_nxt = WRITE_EXTRAM;
             end else if (access_mtime_low(data_addr)) begin 
                data_state_nxt = WRITE_MTIME_LOW;
            end else if (access_mtime_high(data_addr)) begin 
                data_state_nxt = WRITE_MTIME_HIGH;
            end else if (access_mtimecmp_low(data_addr)) begin
                data_state_nxt = WRITE_MTIMECMP_LOW;
            end else if (access_mtimecmp_high(data_addr)) begin
                data_state_nxt = WRITE_MTIMECMP_HIGH;
            end else begin
                data_state_nxt = WAITING;
            end
        end else begin
            data_state_nxt = IDLE;
        end
    end
    READ_UART_DATA: begin
        uart_data_load = 1'b1;
        if (uart_busy) data_state_nxt = READ_UART_DATA;
        else data_state_nxt = FINISH;
    end
    WRITE_UART_DATA: begin
        uart_store = 1'b1;
        if (uart_busy) data_state_nxt = WRITE_UART_DATA;
        else data_state_nxt = FINISH;
    end
    READ_UART_STATE: begin
        uartstate_data_load = 1'b1;
        data_state_nxt = FINISH;
    end
    READ_UART_UNUSED_STATE: begin
        uart_unused_data_load = 1'b1;
        data_state_nxt = FINISH;
    end
    READ_BASERAM: begin
        baseram_data_load = 1'b1;
        if (baseram_busy) data_state_nxt = READ_BASERAM;
        else data_state_nxt = FINISH;
    end
    WRITE_BASERAM: begin
        baseram_store = 1'b1;
        if (baseram_busy) data_state_nxt = WRITE_BASERAM;
        else data_state_nxt = FINISH;
    end
    READ_EXTRAM: begin
        extram_data_load = 1'b1;
        if (extram_busy) data_state_nxt = READ_EXTRAM;
        else data_state_nxt = FINISH;
    end
    WRITE_EXTRAM: begin
        extram_store = 1'b1;
        if (extram_busy) data_state_nxt = WRITE_EXTRAM;
        else data_state_nxt = FINISH;
    end
    READ_MTIME_LOW: begin
        mtime_low_load = 1'b1;
        data_state_nxt = FINISH;
    end
    READ_MTIME_HIGH: begin
        mtime_high_load = 1'b1;
        data_state_nxt = FINISH;
    end
    READ_MTIMECMP_LOW: begin
        mtimecmp_low_load = 1'b1;
        data_state_nxt = FINISH;
    end
    READ_MTIMECMP_HIGH: begin
        mtimecmp_high_load = 1'b1;
        data_state_nxt = FINISH;
    end
    WRITE_MTIME_LOW: begin
        mtime_low_store = 1'b1;
        data_state_nxt = FINISH;
    end
    WRITE_MTIME_HIGH: begin
        mtime_high_store = 1'b1;
        data_state_nxt = FINISH;
    end
    WRITE_MTIMECMP_LOW: begin
        mtimecmp_low_store = 1'b1;
        data_state_nxt = FINISH;
    end
    WRITE_MTIMECMP_HIGH: begin
        mtimecmp_high_store = 1'b1;
        data_state_nxt = FINISH;
    end
    FINISH: begin
        data_state_nxt = IDLE;
    end
    default: data_state_nxt = IDLE;
    endcase
end

endmodule
