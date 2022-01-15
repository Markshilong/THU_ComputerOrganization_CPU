`include "../defines.svh"

module sram_controller (
    input clk, rst,
    // to CPU
    input logic load,
    input logic store,
    input word_t addr,
    input logic[3:0] byte_en,
    input word_t wdata,
    output word_t rdata,
    output logic stall_req,

    // to BUS
    input word_t bus_data_in,
    output word_t bus_data_out,
    output logic write_bus,

    // to SRAM
    output logic[19:0] ram_addr,
    output logic[3:0] ram_be_n,
    output logic ram_ce_n,
    output logic ram_oe_n,
    output logic ram_we_n
);

typedef enum logic[2:0] { 
    IDLE,
    READ_0,
    READ_1,
    WRITE_0,
    WRITE_1,
    WRITE_FINISH
} sram_state_t;

sram_state_t state_now, state_nxt;

assign bus_data_out = wdata;
assign rdata = bus_data_in;

assign stall_req = (state_nxt != IDLE);

always_comb begin
    state_nxt = IDLE;
    unique case(state_now)
    IDLE: begin
        state_nxt = IDLE;
        if (load) state_nxt = READ_0;
        if (store) state_nxt = WRITE_0;
    end
    READ_0: begin
        state_nxt = READ_1;
    end
    READ_1: begin
        state_nxt = IDLE;
    end
    WRITE_0: begin
        state_nxt = WRITE_1;
    end
    WRITE_1: begin
        state_nxt = WRITE_FINISH;
    end
    WRITE_FINISH: begin
        state_nxt = IDLE;
    end
    default: begin 
        state_nxt = IDLE;
    end
    endcase
end

always_comb begin
    ram_ce_n = 1'b1;
    ram_oe_n = 1'b1;
    ram_we_n = 1'b1;
    ram_be_n = ~byte_en;
    ram_addr = addr[21:2];
    write_bus = 1'b0;
    unique case(state_now)
    IDLE: begin
        write_bus = 1'b0;
    end
    READ_0: begin
        ram_ce_n = 1'b0;
        ram_oe_n = 1'b0;
        write_bus = 1'b0;
    end
    READ_1: begin
        ram_ce_n = 1'b0;
        ram_oe_n = 1'b0;
        write_bus = 1'b0;
    end
    WRITE_0: begin
        ram_ce_n = 1'b0;
        ram_we_n = 1'b0;
        write_bus = 1'b1;
    end
    WRITE_1: begin
        ram_ce_n = 1'b0;
        ram_we_n = 1'b0;
        write_bus = 1'b1;
    end
    WRITE_FINISH: begin
        ram_ce_n = 1'b1;
        ram_we_n = 1'b1;
        ram_oe_n = 1'b1;
        write_bus = 1'b1;
    end
    default: begin end
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        state_now <= IDLE;
    end else begin
        state_now <= state_nxt;
    end
end

endmodule

