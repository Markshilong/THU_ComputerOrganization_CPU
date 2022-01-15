`include "../../defines.svh"

module ex_mem (
    input clk, rst,

    input bit_t stall_ex,
    input bit_t stall_mem,
    input bit_t trap,

    input op_t ex_op,
    input word_t ex_inst,
    input except_t ex_except,
    input bit_t ex_gpr_we,
    input regaddr_t ex_gpr_waddr,
    input word_t ex_gpr_wdata,
    input memory_t ex_memory,
    input csraddr_t ex_csr_waddr,
    input bit_t ex_csr_we,
    input word_t ex_csr_wdata,
    input word_t ex_pc,

    output op_t mem_op,
    output word_t mem_inst,
    output except_t mem_except,
    output bit_t mem_gpr_we,
    output regaddr_t mem_gpr_waddr,
    output word_t mem_gpr_wdata,
    output memory_t mem_memory,
    output csraddr_t mem_csr_waddr,
    output bit_t mem_csr_we,
    output word_t mem_csr_wdata,
    output word_t mem_pc
);

always_ff @(posedge clk) begin
    if (rst | trap | (stall_ex && ~stall_mem)) begin
        mem_op <= OP_NOP;
        mem_inst <= `NOP_INST;
        mem_except <= '0;
        mem_gpr_we <= '0;
        mem_gpr_waddr <= '0;
        mem_gpr_wdata <= '0;
        mem_memory <= '0;
        mem_csr_waddr <= '0;
        mem_csr_we <= '0;
        mem_csr_wdata <= '0;
        mem_pc <= '0;
    end else if (~stall_ex) begin
        mem_op <= ex_op;
        mem_inst <= ex_inst;
        mem_except <= ex_except;
        mem_gpr_we <= ex_gpr_we;
        mem_gpr_waddr <= ex_gpr_waddr;
        mem_gpr_wdata <= ex_gpr_wdata;
        mem_memory <= ex_memory;
        mem_csr_waddr <= ex_csr_waddr;
        mem_csr_we <= ex_csr_we;
        mem_csr_wdata <= ex_csr_wdata;
        mem_pc <= ex_pc;
    end
end

endmodule

