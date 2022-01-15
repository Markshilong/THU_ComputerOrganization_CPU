`include "../../defines.svh"

module mem_wb (
    input clk, rst,

    input bit_t stall_mem,
    input bit_t stall_wb,

    input regaddr_t mem_gpr_waddr,
    input word_t mem_gpr_wdata,
    input bit_t mem_gpr_we,

    output regaddr_t wb_gpr_waddr,
    output word_t wb_gpr_wdata,
    output bit_t wb_gpr_we
);

always_ff @(posedge clk) begin
    if (rst | (stall_mem && ~stall_wb)) begin
        wb_gpr_wdata <= '0;
        wb_gpr_we <= '0;
        wb_gpr_waddr <= '0;
    end else if (~stall_mem) begin
        wb_gpr_wdata <= mem_gpr_wdata;
        wb_gpr_we <= mem_gpr_we;
        wb_gpr_waddr <= mem_gpr_waddr;
    end
end

endmodule
