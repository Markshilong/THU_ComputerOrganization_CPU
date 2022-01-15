`include "../../defines.svh"

module forward_unit (
    // request from id stage
    input regaddr_t raddr1,
    input regaddr_t raddr2,
    
    // bypass from ex stage
    input bit_t ex_gpr_we,
    input regaddr_t ex_gpr_waddr,
    input word_t ex_gpr_wdata,
    input bit_t ex_memory_load,
    // bypass from mem stage
    input bit_t mem_gpr_we,
    input regaddr_t mem_gpr_waddr,
    input word_t mem_gpr_wdata,
    input bit_t mem_memory_load,
    // bypass from wb stage(also from regfile)
    input word_t gpr_rdata1,
    input word_t gpr_rdata2,

    // output to id stage
    output word_t true_gpr_rdata1,
    output word_t true_gpr_rdata2,
    // id stall req
    output bit_t id_stall_req
);

always_comb begin: reg1_forward
    if (raddr1 == 5'b0) begin
        true_gpr_rdata1 = 32'b0;
    end else if (ex_gpr_we && ex_gpr_waddr == raddr1) begin
        true_gpr_rdata1 = ex_gpr_wdata;
    end else if (mem_gpr_we && mem_gpr_waddr == raddr1) begin
        true_gpr_rdata1 = mem_gpr_wdata;
    end else begin
        true_gpr_rdata1 = gpr_rdata1;
    end
end

always_comb begin: reg2_forward
    if (raddr2 == 5'b0) begin
        true_gpr_rdata2 = 32'b0;
    end else if (ex_gpr_we && ex_gpr_waddr == raddr2) begin
        true_gpr_rdata2 = ex_gpr_wdata;
    end else if (mem_gpr_we && mem_gpr_waddr == raddr2) begin
        true_gpr_rdata2 = mem_gpr_wdata;
    end else begin
        true_gpr_rdata2 = gpr_rdata2;
    end
end

bit_t ex_load_relation, mem_load_relation;
assign ex_load_relation = ( ex_memory_load &&
    (ex_gpr_waddr == raddr1 && raddr1 != 5'b0) || 
    (ex_gpr_waddr == raddr2 && raddr2 != 5'b0)
);
assign mem_load_relation = ( mem_memory_load &&
    (mem_gpr_waddr == raddr1 && raddr1 != 5'b0) || 
    (mem_gpr_waddr == raddr2 && raddr2 != 5'b0)
);
assign id_stall_req = ex_load_relation | mem_load_relation;

endmodule

