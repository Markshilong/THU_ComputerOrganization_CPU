`include "defines.svh"

module riscv_soc (
    input clk, rst,

    // CPLD UART
    output logic uart_rdn,
    output logic uart_wrn,
    input logic uart_dataready,
    input logic uart_tbre,
    input logic uart_tsre,

    // BASERAM
    inout word_t base_ram_data,
    output logic[19:0] base_ram_addr,
    output logic[3:0] base_ram_be_n,
    output logic base_ram_ce_n,
    output logic base_ram_oe_n,
    output logic base_ram_we_n,

    // EXTRAM
    inout word_t ext_ram_data,
    output logic[19:0] ext_ram_addr,
    output logic[3:0] ext_ram_be_n,
    output logic ext_ram_ce_n,
    output logic ext_ram_oe_n,
    output logic ext_ram_we_n,

    output logic[15:0] leds
);

logic base_sram_load;
logic base_sram_store;
word_t base_sram_addr;
word_t base_sram_wdata;
logic[3:0] base_sram_byte_en;
word_t base_sram_rdata;
logic base_sram_stall_req;
word_t baseram_bus_data_in;
word_t baseram_bus_data_out;
logic baseram_write_bus;

logic ext_sram_load;
logic ext_sram_store;
word_t ext_sram_addr;
word_t ext_sram_wdata;
logic[3:0] ext_sram_byte_en;
word_t ext_sram_rdata;
logic ext_sram_stall_req;
word_t extram_bus_data_in;
word_t extram_bus_data_out;
logic extram_write_bus;

logic uart_load;
logic uart_store;
word_t uart_wdata;
word_t uart_rdata;
logic uart_stall_req;
word_t uart_bus_data_in;
word_t uart_bus_data_out;
logic uart_write_bus;

// extram BUS control
assign ext_ram_data = extram_write_bus ? extram_bus_data_out : 32'bz;
assign extram_bus_data_in = ext_ram_data;
// baseram BUS control
// bus write priority: UART > BASERAM
word_t write_bus_data;
// 3-state gate
assign write_bus_data = uart_write_bus ? uart_bus_data_out : baseram_bus_data_out;
assign base_ram_data = (uart_write_bus | baseram_write_bus) ? write_bus_data : 32'bz;
assign baseram_bus_data_in = base_ram_data;
assign uart_bus_data_in = base_ram_data;

// connection
word_t if_address, mem_address;
bit_t trap_flag;
word_t trap_target;
bit_t if_load, mem_load, mem_store;
word_t if_rdata, mem_wdata, mem_rdata;
bit_t if_stall_req, mem_stall_req;
logic[3:0] mem_byte_en;

bit_t time_int, clear_mip;

assign leds = { 15'b0, time_int };

sram_controller baseram_controller(
    .clk(clk),
    .rst(rst),
    
    .load(base_sram_load),
    .store(base_sram_store),
    .addr(base_sram_addr),
    .byte_en(base_sram_byte_en),
    .wdata(base_sram_wdata),
    .rdata(base_sram_rdata),
    .stall_req(base_sram_stall_req),

    .bus_data_in(baseram_bus_data_in),
    .bus_data_out(baseram_bus_data_out),
    .write_bus(baseram_write_bus),

    .ram_addr(base_ram_addr),
    .ram_be_n(base_ram_be_n),
    .ram_ce_n(base_ram_ce_n),
    .ram_oe_n(base_ram_oe_n),
    .ram_we_n(base_ram_we_n)
);

sram_controller extram_controller(
    .clk(clk),
    .rst(rst),

    .load(ext_sram_load),
    .store(ext_sram_store),
    .addr(ext_sram_addr),
    .byte_en(ext_sram_byte_en),
    .wdata(ext_sram_wdata),
    .rdata(ext_sram_rdata),
    .stall_req(ext_sram_stall_req),

    .bus_data_in(extram_bus_data_in),
    .bus_data_out(extram_bus_data_out),
    .write_bus(extram_write_bus),

    .ram_addr(ext_ram_addr),
    .ram_be_n(ext_ram_be_n),
    .ram_ce_n(ext_ram_ce_n),
    .ram_oe_n(ext_ram_oe_n),
    .ram_we_n(ext_ram_we_n)
);

uart_controller uart_controller(
    .clk(clk),
    .rst(rst),

    .load(uart_load),
    .store(uart_store),
    .wdata(uart_wdata),
    .rdata(uart_rdata),
    .stall_req(uart_stall_req),

    .bus_data_in(uart_bus_data_in),
    .bus_data_out(uart_bus_data_out),
    .write_bus(uart_write_bus),

    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn)
);

bus bus_crossbar(
    .clk(clk),
    .rst(rst),
    // CPU inst
    .if_address(if_address),
    .if_load(if_load),
    .trap_flag(trap_flag),
    .trap_target(trap_target),
    .if_rdata(if_rdata),
    .if_stall_req(if_stall_req),
    // CPU data
    .mem_address(mem_address),
    .mem_load(mem_load),
    .mem_store(mem_store),
    .mem_byte_en(mem_byte_en),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_stall_req(mem_stall_req),
    .time_int(time_int),
    .clear_mip(clear_mip),

    // UART controller
    .uart_load(uart_load),
    .uart_store(uart_store),
    .uart_wdata(uart_wdata),
    .uart_rdata(uart_rdata),
    .uart_busy(uart_stall_req),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .uart_dataready(uart_dataready),

    // BASERAM controller
    .baseram_load(base_sram_load),
    .baseram_store(base_sram_store),
    .baseram_addr(base_sram_addr),
    .baseram_byte_en(base_sram_byte_en),
    .baseram_wdata(base_sram_wdata),
    .baseram_rdata(base_sram_rdata),
    .baseram_busy(base_sram_stall_req),

    // EXTRAM controller
    .extram_load(ext_sram_load),
    .extram_store(ext_sram_store),
    .extram_addr(ext_sram_addr),
    .extram_byte_en(ext_sram_byte_en),
    .extram_wdata(ext_sram_wdata),
    .extram_rdata(ext_sram_rdata),
    .extram_busy(ext_sram_stall_req)
);

cpu cpu_instance(
    .clk(clk),
    .rst(rst),
    // IF stage signals
    .if_address(if_address),
    .if_load(if_load),
    .trap_flag(trap_flag),
    .trap_target(trap_target),
    .if_rdata(if_rdata),
    .ibus_stall_req(if_stall_req),
    // MEM stage signals
    .mem_address(mem_address),
    .mem_load(mem_load),
    .mem_store(mem_store),
    .mem_wdata(mem_wdata),
    .mem_byte_en(mem_byte_en),
    .mem_rdata(mem_rdata),
    .mem_stall_req(mem_stall_req),
    // interrput
    .time_int(time_int),
    .clear_mip(clear_mip)
);

endmodule
