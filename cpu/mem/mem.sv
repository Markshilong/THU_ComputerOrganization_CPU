`include "../../defines.svh"

module mem (
    input op_t op,
    input memory_t memory,
    input word_t gpr_wdata_tmp,
    input except_t except_tmp,

    output word_t gpr_wdata,
    output except_t mem_except,

    // to data bus
    output word_t mem_address,
    output bit_t mem_load,
    output bit_t mem_store,
    output word_t mem_wdata,
    output logic[3:0] mem_byte_en,
    input word_t mem_rdata
);

// send requests to bus
assign mem_address = memory.address;
assign mem_load = memory.load;
assign mem_store = memory.store;
assign mem_wdata = memory.wdata;
assign mem_byte_en = memory.byte_en;

// handle 非对齐指令的新写入数据
always_comb begin
    unique case(op)
    OP_LB: begin
        unique case(memory.address[1:0])
        2'b00: gpr_wdata = { {24{mem_rdata[7]}}, mem_rdata[7:0] };
        2'b01: gpr_wdata = { {24{mem_rdata[15]}}, mem_rdata[15:8] };
        2'b10: gpr_wdata = { {24{mem_rdata[23]}}, mem_rdata[23:16] };
        2'b11: gpr_wdata = { {24{mem_rdata[31]}}, mem_rdata[31:24] };
        endcase
    end
    OP_LH: gpr_wdata = memory.address[1] ? { {16{mem_rdata[31]}}, mem_rdata[31:16] } : { {16{mem_rdata[15]}}, mem_rdata[15:0] };
    OP_LW: gpr_wdata = mem_rdata;
    OP_LBU: begin
        unique case(memory.address[1:0])
        2'b00: gpr_wdata = { 24'b0, mem_rdata[7:0] };
        2'b01: gpr_wdata = { 24'b0, mem_rdata[15:8] };
        2'b10: gpr_wdata = { 24'b0, mem_rdata[23:16] };
        2'b11: gpr_wdata = { 24'b0, mem_rdata[31:24] };
        endcase
    end
    OP_LHU: gpr_wdata = memory.address[1] ? { 16'b0, mem_rdata[31:16] } : { 16'b0, mem_rdata[15:0] };
    default: gpr_wdata = gpr_wdata_tmp;
    endcase
end

// TODO: mem excepts
assign mem_except = except_tmp;

endmodule
