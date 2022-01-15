// simple wrapper of RAMs
`include "../defines.svh"

// Simple dual port BRAM
// A端口只写，B端口只读，已经内置前传
// 使用SDP_RAM默认其读延迟为1
module bram #(
    parameter DATA_WIDTH = 32,
    parameter SIZE = 128,
    parameter LATENCY = 1
) (
    input logic clk,
    input logic rst,

    input logic wea,
    input logic ena,
    input logic enb,

    input logic[$clog2(SIZE)-1:0] addra,
    input logic[$clog2(SIZE)-1:0] addrb,

    input logic [DATA_WIDTH-1:0] dina,
    output logic [DATA_WIDTH-1:0] doutb
);

logic prev_wea;
logic[$clog2(SIZE)-1:0] prev_addra;
logic [DATA_WIDTH-1:0] prev_dina;
logic[$clog2(SIZE)-1:0] prev_addrb;
logic [DATA_WIDTH-1:0] doutb_unsafe;

// pipe a cycle to match BRAM feature
always_ff @(posedge clk) begin
    if (rst) begin
        prev_wea <= '0;
        prev_addra <= '0;
        prev_dina <= '0;
        prev_addrb <= '0;
    end else begin
        prev_wea <= wea;
        prev_addra <= addra;
        prev_dina <= dina;
        prev_addrb <= addrb;
    end
end

// data bypass
always_comb begin
    if (prev_wea && prev_addra == prev_addrb) begin
        doutb = prev_dina;
    end else begin
        doutb = doutb_unsafe;
    end
end

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2019.2
   xpm_memory_sdpram #(
       // common module parameters
        .CLOCKING_MODE("common_clock"), // String
        .MEMORY_PRIMITIVE("block"),      // String
        .ECC_MODE("no_ecc"),            // String
        .MEMORY_INIT_FILE("none"),      // String
        .MEMORY_INIT_PARAM("0"),        // String
        .MEMORY_OPTIMIZATION("true"),   // String
        .AUTO_SLEEP_TIME(0),            // DECIMAL
        .CASCADE_HEIGHT(0),             // DECIMAL
        .MESSAGE_CONTROL(0),            // DECIMAL
        .MEMORY_SIZE(DATA_WIDTH * SIZE),// DECIMAL
        .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
        .USE_MEM_INIT(0),               // DECIMAL
        .WAKEUP_TIME("disable_sleep"),  // String
       // Port A (write) params
        .ADDR_WIDTH_A($clog2(SIZE)),               // DECIMAL
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH),        // DECIMAL
        .RST_MODE_A("SYNC"),            // String
        .WRITE_DATA_WIDTH_A(DATA_WIDTH),        // DECIMAL
       // Port B (read) params
        .ADDR_WIDTH_B($clog2(SIZE)),               // DECIMAL
        .READ_DATA_WIDTH_B(DATA_WIDTH),         // DECIMAL
        .READ_LATENCY_B(LATENCY),       // DECIMAL
        .READ_RESET_VALUE_B("0"),       // String
        .RST_MODE_B("SYNC"),            // String
        .WRITE_MODE_B("read_first")      // String
   ) xpm_memory_sdpram_inst (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb_unsafe),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
endmodule
