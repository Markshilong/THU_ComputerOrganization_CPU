`include "../defines.svh"

module uart_controller (
    input clk, rst,
    // to CPU
    input logic load,
    input logic store,
    input word_t wdata,
    output word_t rdata,
    output logic stall_req,
    
    // to BUS
    input word_t bus_data_in,
    output word_t bus_data_out,
    output logic write_bus,
    
    // to CPLD UART
    output logic uart_rdn,
    output logic uart_wrn
);

// uart FSM states
typedef enum logic[3:0] {
    IDLE,
    READ_WAIT_READY,
    READ_RECEIVING_0,
    READ_RECEIVING_1,
    READ_RECEIVING_2,
    READ_RECEIVING,
    READ_FINISH,

    WRITE_BEGIN_1,
    WRITE_BEGIN_2,
    WRITE_BEGIN_3,
    WRITE_BEGIN_4,
    WRITE_BEGIN_5
} uart_state_t;

uart_state_t state_now, state_nxt;

// bus 
assign bus_data_out = { 24'b0, wdata[7:0] };

always_ff @(posedge clk) begin
    if (state_now == READ_RECEIVING) begin
        rdata <= { 24'b0, bus_data_in[7:0] };
    end
end

assign stall_req = (state_nxt != IDLE);

// uart FSM updates
always_comb begin: uart_fsm
    unique case (state_now)
    IDLE: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = IDLE;
        if (load) state_nxt = READ_RECEIVING_0;
        if (store) state_nxt = WRITE_BEGIN_1;
    end
    // READ_WAIT_READY: begin
    //     write_bus = 1'b0;
    //     if (uart_dataready) begin
    //         state_nxt = READ_RECEIVING_0;
    //     end else begin
    //         state_nxt = READ_WAIT_READY;
    //     end
    // end
    READ_RECEIVING_0: begin
        uart_rdn = 1'b0;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = READ_RECEIVING_1;
    end
    READ_RECEIVING_1: begin
        uart_rdn = 1'b0;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = READ_RECEIVING;
    end
    READ_RECEIVING: begin
        uart_rdn = 1'b0;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = READ_FINISH;
    end
    READ_FINISH: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = IDLE;
    end

    WRITE_BEGIN_1: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b0;
        write_bus = 1'b1;
        state_nxt = WRITE_BEGIN_2;
    end
    WRITE_BEGIN_2: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b0;
        write_bus = 1'b1;
        state_nxt = WRITE_BEGIN_3;
    end
    WRITE_BEGIN_3: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b0;
        write_bus = 1'b1;
        state_nxt = WRITE_BEGIN_4;
    end
    WRITE_BEGIN_4: begin
        uart_rdn = 1'b1;
        uart_wrn = 1'b0;
        write_bus = 1'b1;
        state_nxt = IDLE;
    end
    // WRITE_WAIT_READY: begin
    //     // write_bus = 1'b1;
    //     uart_wrn = 1'b1;
    //     if (uart_tbre) state_nxt = WRITE_WAIT_FINISH;
    //     else state_nxt = WRITE_WAIT_READY;
    // end
    // WRITE_WAIT_FINISH: begin
    //     // write_bus = 1'b1;
    //     uart_wrn = 1'b1;
    //     if (uart_tsre) state_nxt = IDLE;
    //     else state_nxt = WRITE_WAIT_FINISH;
    // end
    default: begin 
        uart_rdn = 1'b1;
        uart_wrn = 1'b1;
        write_bus = 1'b0;
        state_nxt = IDLE;
    end
    endcase
end

// state update
always_ff @(posedge clk) begin
    if (rst) begin
        state_now <= IDLE;
    end else begin
        state_now <= state_nxt;
    end
end

endmodule
