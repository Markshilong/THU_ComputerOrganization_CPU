`include "../../defines.svh"

module id_ex (
    input clk, rst,

    input bit_t stall_id,
    input bit_t stall_ex,
    input bit_t trap,
    input bit_t branch_flag,

    input word_t id_pc,
    input word_t id_inst,
    input except_t id_except,
    input bit_t id_gpr_we,
    input regaddr_t id_gpr_waddr,
    input op_t id_op,
    input word_t id_imm,
    input logic[4:0] id_shamt,
    input word_t id_gpr_rdata1,
    input word_t id_gpr_rdata2,
    input bit_t id_btb_branch,
    input word_t id_btb_target,

    output word_t ex_pc,
    output word_t ex_inst,
    output except_t ex_except,
    output bit_t ex_gpr_we,
    output regaddr_t ex_gpr_waddr,
    output op_t ex_op,
    output word_t ex_imm,
    output logic[4:0] ex_shamt,
    output word_t ex_gpr_rdata1,
    output word_t ex_gpr_rdata2,
    output bit_t ex_btb_branch,
    output word_t ex_btb_target
);

always_ff @(posedge clk) begin
    if (rst | ((trap | branch_flag) & ~stall_ex) | (stall_id && ~stall_ex)) begin
        ex_pc <= '0;
        ex_inst <= `NOP_INST;
        ex_except <= '0;
        ex_gpr_we <= '0;
        ex_gpr_waddr <= '0;
        ex_op <= OP_NOP;
        ex_imm <= '0;
        ex_shamt <= '0;
        ex_gpr_rdata1 <= '0;
        ex_gpr_rdata2 <= '0;
        ex_btb_branch <= '0;
        ex_btb_target <= '0;
    end else if (~stall_id) begin
        ex_pc <= id_pc;
        ex_inst <= id_inst;
        ex_except <= id_except;
        ex_gpr_we <= id_gpr_we;
        ex_gpr_waddr <= id_gpr_waddr;
        ex_op <= id_op;
        ex_imm <= id_imm;
        ex_shamt <= id_shamt;
        ex_gpr_rdata1 <= id_gpr_rdata1;
        ex_gpr_rdata2 <= id_gpr_rdata2;
        ex_btb_branch <= id_btb_branch;
        ex_btb_target <= id_btb_target;
    end
end

endmodule
