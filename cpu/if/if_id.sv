`include "../../defines.svh"

module if_id (
    input clk, rst,

    input bit_t stall_if,
    input bit_t stall_id,
    input bit_t trap,
    input bit_t branch_flag,

    input except_t if_except,
    input word_t if_pc,
    input word_t if_inst,
    input bit_t if_btb_branch,
    input word_t if_btb_target,

    output except_t id_except,
    output word_t id_pc,
    output word_t id_inst,
    output bit_t id_btb_branch,
    output word_t id_btb_target
);

always_ff @(posedge clk) begin
    if (rst | trap | branch_flag | (stall_if && ~stall_id)) begin
        id_except <= '0;
        id_pc <= '0;
        id_inst <= `NOP_INST;
        id_btb_branch <= '0;
        id_btb_target <= '0;
    end else if (~stall_if) begin
        id_except <= if_except;
        id_pc <= if_pc;
        id_inst <= if_inst;
        id_btb_branch <= if_btb_branch;
        id_btb_target <= if_btb_target;
    end
end

endmodule

