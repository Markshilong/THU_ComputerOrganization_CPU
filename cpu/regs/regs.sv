`include "../../defines.svh"

module regfile (
    input clk, rst,
    
    // write port 1
    input bit_t gpr_we,
    input regaddr_t gpr_waddr,
    input word_t gpr_wdata,

    // read port 1
    input regaddr_t gpr_raddr1,
    output word_t gpr_rdata1,

   // read port 2
    input regaddr_t gpr_raddr2,
    output word_t gpr_rdata2
);

reg[31:0] registers[0:`REG_NUM-1];

always_ff @(posedge clk) begin
    registers[0] <= '0;
end

// write port 1
genvar i;
generate
    for (i = 1; i < `REG_NUM; ++i) begin
        always_ff @(posedge clk) begin
            if (rst) begin
                registers[i] <= '0;
            end else if (gpr_we && gpr_waddr == i) begin
                registers[i] <= gpr_wdata;
            end
        end
    end
endgenerate

// read port 1
always_comb begin : read_port1
    if (gpr_we && gpr_raddr1 == gpr_waddr) begin
        gpr_rdata1 = gpr_wdata;
    end else begin
        gpr_rdata1 = registers[gpr_raddr1];
    end
end

// read port 2
always_comb begin : read_port2
    if (gpr_we && gpr_raddr2 == gpr_waddr) begin
        gpr_rdata2 = gpr_wdata;
    end else begin
        gpr_rdata2 = registers[gpr_raddr2];
    end
end

endmodule
