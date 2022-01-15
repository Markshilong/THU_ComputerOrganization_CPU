`include "../../defines.svh"

// 直接映射I-CACHE
module fetch #(
    parameter LINE_NUM = 256,
    parameter BTB_NUM = 128
) (
    input clk, rst,

    input bit_t stall,

    input bit_t ibus_stall,
    input bit_t backend_stall,
    input bit_t branch_flag,
    input word_t branch_target,

    input bit_t trap_flag,
    input word_t trap_target,

    input bit_t flush_icache,

    // from ex btb update info
    input word_t ex_pc,
    input bit_t update_btb,
    input word_t true_btb_target,

    output bit_t if_stall_req,
    output word_t pc,
    output word_t inst,
    output bit_t predict_branch,
    output word_t predict_branch_target,
    output except_t icache_except,
    // to/from inst bus
    input word_t ibus_inst,
    output word_t if_address,
    output bit_t if_load
);

// pipeline first stage, PC stage
// give I-CACHE a addr, Icache will return in next cycle(icache stage)
// pc_reg
word_t pc_now, pc_nxt;
// BTB
localparam int BTB_INDEX_WIDTH = $clog2(BTB_NUM);
localparam int BTB_TAG_WIDTH = 32 - 2 - BTB_INDEX_WIDTH;
localparam int BTB_LINE_WIDTH = BTB_TAG_WIDTH + 1 + 30;
typedef logic[BTB_INDEX_WIDTH-1:0] btb_index_t;
typedef logic[BTB_TAG_WIDTH-1:0] btb_tag_t;
typedef struct packed {
    logic[BTB_TAG_WIDTH-1:0] tag;
    logic[29:0] target;
    logic valid;
} btb_line_t;
btb_line_t btb[BTB_NUM-1:0];
bit_t if_predict_branch;
word_t if_predict_pc_nxt;
btb_line_t btb_line_access;
assign btb_line_access = btb[pc_now[BTB_INDEX_WIDTH+1:2]];
assign if_predict_branch = btb_line_access.valid && (btb_line_access.tag == pc_now[31:BTB_INDEX_WIDTH+2]);
assign if_predict_pc_nxt = { btb_line_access.target, 2'b00 };

genvar i;
for (i = 0; i < BTB_NUM; ++i) begin
    always_ff @(posedge clk) begin
        if (rst) begin
            btb[i] <= '0;
        end else if (update_btb && i == ex_pc[BTB_INDEX_WIDTH+1:2]) begin
            btb[i].tag <= ex_pc[31:BTB_INDEX_WIDTH+2];
            btb[i].target <= true_btb_target[31:2];
            btb[i].valid <= 1'b1;
        end 
    end
end

always_comb begin
    // priority from low to high
    if (stall) pc_nxt = pc_now;
    else if (if_predict_branch) pc_nxt = if_predict_pc_nxt;
    else pc_nxt = { pc_now[31:2] + 30'b1, 2'b0 };

    if (branch_flag) pc_nxt = branch_target;

    if (trap_flag) pc_nxt = trap_target;
end

always_ff @(posedge clk) begin
    if (rst) begin
        pc_now <= `PC_RESET_VECTOR;
    end else begin
        pc_now <= pc_nxt;
    end
end

// TODO: inst exceptions
except_t if_except;
assign if_except = '0;


// pipeline seconde stage, i-cache stage, 
// confirm whether cache hit to deside give or not give bus request.
// also need to receive flush signal from EX stage to flush all icache.

// addr: tag | index | 00
localparam int INDEX_WIDTH = $clog2(LINE_NUM);
localparam int TAG_WIDTH = 32 - 2 - INDEX_WIDTH;

typedef struct packed {
    logic[TAG_WIDTH-1:0] tag;
    word_t data;
} line_t;
typedef logic[INDEX_WIDTH-1:0] index_t;
typedef logic[TAG_WIDTH-1:0] tag_t;
function index_t get_index( input word_t addr );
    return addr[INDEX_WIDTH+1 : 2];
endfunction;
function tag_t get_tag( input word_t addr );
    return addr[31 : 2+INDEX_WIDTH];
endfunction;
function tag_t get_cacheline_tag( input line_t line );
    return line[TAG_WIDTH+32-1 : 32];
endfunction;
function word_t get_cacheline_data( input line_t line );
    return line[31:0];
endfunction;
typedef enum logic[2:0] {
    IDLE,
    FETCH,
    WRITE,
    FLUSH,
    WITHDRAWING_FETCH,
    WITHDRAWING_IDLE,
    WAITING_FLUSH
} icache_state_t;
icache_state_t state_now, state_nxt;

// ICACHE read signals
index_t icache_idx;
assign icache_idx = get_index(pc_now);
line_t icache_line;

// ICACHE instance
localparam int CACHELINE_WIDTH = TAG_WIDTH + 32;
// cache data: valid | tag | data
logic[LINE_NUM-1:0] icache_valid;
bit_t valid_bit;
assign valid_bit = icache_valid[icache_idx];
word_t icache_pc;
index_t pipe_idx;
assign pipe_idx = get_index(icache_pc);
tag_t pc_tag;
assign pc_tag = get_tag(icache_pc);
bram #(
    .DATA_WIDTH($bits(line_t)),
    .SIZE(LINE_NUM)
) icache (
    .clk(clk),
    .rst(rst),
    // port A for write
    .ena(1'b1),
    .wea(state_now == WRITE),
    .addra(pipe_idx),
    .dina({pc_tag, ibus_inst}),
    // port B for read
    .enb(~stall),
    .addrb(icache_idx),
    .doutb(icache_line)
);
always_ff @(posedge clk) begin
    if (rst | flush_icache) begin
        icache_valid <= '0;
    end else if (state_now == WRITE) begin
        icache_valid[pipe_idx] <= 1'b1;
    end
end

bit_t icache_valid_bit;
tag_t icache_tag;
assign icache_tag = get_cacheline_tag(icache_line);
word_t icache_data;
assign icache_data = get_cacheline_data(icache_line);
bit_t hit;
assign hit = icache_valid_bit && (icache_tag == pc_tag) && (~flush_icache);

assign pc = icache_pc;
always_ff @(posedge clk) begin
    if (rst | trap_flag | branch_flag) begin
        icache_pc <= '0;
        icache_except <= '0;
        icache_valid_bit <= '0;
        predict_branch <= '0;
        predict_branch_target <= '0;
    end else if (~stall) begin
        icache_pc <= pc_now;
        icache_except <= if_except;
        icache_valid_bit <= valid_bit;
        predict_branch <= if_predict_branch;
        predict_branch_target <= if_predict_pc_nxt;
    end
end

assign if_stall_req = (state_nxt != IDLE);
always_comb begin
    unique case(state_now)
    IDLE: begin
        if (backend_stall) begin
            if (trap_flag | branch_flag) state_nxt = WAITING_FLUSH;
            else state_nxt = IDLE;
        end else if (trap_flag | branch_flag) state_nxt = WITHDRAWING_IDLE;
        else if (hit) state_nxt = IDLE;
        else if (flush_icache) state_nxt = FLUSH;
        else state_nxt = FETCH;
    end
    WAITING_FLUSH: begin
        if (backend_stall) state_nxt = WAITING_FLUSH;
        else state_nxt = WITHDRAWING_IDLE;
    end
    FETCH: begin
        if (trap_flag | branch_flag) state_nxt = WITHDRAWING_FETCH;
        else if (ibus_stall) state_nxt = FETCH;
        else state_nxt = WRITE;
    end
    WITHDRAWING_FETCH: begin
        if (ibus_stall) state_nxt = WITHDRAWING_FETCH;
        else state_nxt = IDLE;
    end
    WITHDRAWING_IDLE: begin
        state_nxt = IDLE;
    end
    WRITE: state_nxt = IDLE;
    FLUSH: state_nxt = IDLE;
    default: state_nxt = IDLE;
    endcase
end
// send and receive bus requests
assign if_address = icache_pc;
always_comb begin
    unique case(state_now)
    IDLE: if_load = 1'b0;
    FETCH: if_load = 1'b1;
    WITHDRAWING_FETCH: if_load = 1'b0;
    WITHDRAWING_IDLE: if_load = 1'b0;
    WRITE: if_load = 1'b0;
    FLUSH: if_load = 1'b0;
    WAITING_FLUSH: if_load = 1'b0;
    default: if_load = 1'b0;
    endcase
end
always_ff @(posedge clk) begin
    if (rst) begin
        state_now <= FLUSH;
    end else begin
        state_now <= state_nxt;
    end
end
always_comb begin
    if (hit) inst = icache_data;
    else if (state_now == WRITE) inst = ibus_inst;
    else inst = `NOP_INST;
end

endmodule

