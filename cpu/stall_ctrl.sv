`include "../defines.svh"

module stall_ctrl (
    input bit_t if_stall_req,
    input bit_t id_stall_req,
    input bit_t mem_stall_req,

    output bit_t stall_pc,
    output bit_t stall_if,
    output bit_t stall_id,
    output bit_t stall_ex,
    output bit_t stall_mem,
    output bit_t stall_wb
);

always_comb begin
    stall_pc = '0;
    stall_if = '0;
    stall_id = '0;
    stall_ex = '0;
    stall_mem = '0;
    stall_wb = '0;

    if (if_stall_req) begin
        stall_pc = 1'b1;
        stall_if = 1'b1;
    end
    if (id_stall_req) begin
        stall_pc = 1'b1;
        stall_if = 1'b1;
        stall_id = 1'b1;
    end
    if (mem_stall_req) begin
        stall_pc = 1'b1;
        stall_if = 1'b1;
        stall_id = 1'b1;
        stall_ex = 1'b1;
        stall_mem = 1'b1;
    end
end

endmodule
