`include "../../defines.svh"

module csr_regs (
    input clk, rst,

    input word_t inst,
    // read port 1
    input csraddr_t csr_raddr,
    output word_t csr_rdata,

    // write port 1
    input csraddr_t csr_waddr,
    input bit_t csr_we,
    input word_t csr_wdata,

    // exception handle
    input word_t pc,
    input except_t except,

    output bit_t trap_flag,
    output word_t trap_target,
    output bit_t time_int_flag,
    input bit_t time_int,
    input bit_t clear_mip
);

// CSR spec
// WPRI: Reserved Writes Preserve Values, Reads Ignore Values
// WLRL: Write/Read Only Legal Values
// WARL: Write Any Values, Reads Legal Values

// mstatus,mtvec,mscratch,mepc,mcause,mtval,satp
logic[31:0] registers[0:8];
logic[1:0] mode;
// mstatus.mpp: [12:11]
// mtvec.base: [31:2], mtvec.mode: [1:0]
// mscratch
// mepc
// mcause: exception/interrupt code
// mtval
// mie.mtie
// mip.mtip
// satp.mode: [31], satp.asid: [30:22], satp.ppn: [21:0]

assign time_int_flag = registers[7][7] && registers[8][7] && registers[0][3];

// read
always_comb begin
    if (csr_we && csr_waddr == csr_raddr) begin
        csr_rdata = csr_wdata;
    end else begin
        unique case(csr_raddr)
        12'h300: begin
            if (trap_flag) begin
                csr_rdata = {registers[0][31:13], mode, registers[0][10:0]};
            end else begin
                csr_rdata = registers[0]; // mstatus
            end
        end
        12'h304: csr_rdata = registers[7]; // mie
        12'h305: csr_rdata = registers[1]; // mtvec
        12'h340: csr_rdata = registers[2]; // mscratch
        12'h341: begin
            if (trap_flag) begin
                csr_rdata = pc;
            end else begin
                csr_rdata = registers[3]; // mepc
            end
        end
        12'h342: begin
            if (except.ecall_umode) begin
                csr_rdata = `ECALL_U;
            end else if (except.breakpoint) begin
                csr_rdata = `BREAKPOINT;
            end else begin
                csr_rdata = registers[4]; // mcause
            end
        end
        12'h343: csr_rdata = registers[5]; // mtval
        12'h344: csr_rdata = registers[8]; // mip
        12'h180: csr_rdata = registers[6]; // satp
        default: csr_rdata = '0;
        endcase
    end
end

assign trap_flag = (except.breakpoint | except.ecall_umode | except.timer_int);
assign trap_target = registers[1]; // mtvec

// write
always_ff @(posedge clk) begin
    if (rst) begin
        registers[0] <= {19'b0, `MODE_M, 3'b0, 1'b1, 3'b0, 1'b1, 3'b0}; // set mstatus.mie & mpie = 1'b1;
        for (int i = 1; i < 8; ++i) begin
            registers[i] <= '0;
        end
    end else if (except.ecall_umode) begin
        registers[0] <= {registers[0][31:13], mode, registers[0][10:8], registers[0][3], registers[0][6:4], 2'b0, registers[0][1:0]};
        registers[3] <= pc;
        registers[4] <= `ECALL_U;
        registers[5] <= '0;
    end else if (except.breakpoint) begin
        registers[0] <= {registers[0][31:13], mode, registers[0][10:8], registers[0][3], registers[0][6:4], 2'b0, registers[0][1:0]};
        registers[3] <= pc;
        registers[4] <= `BREAKPOINT;
        registers[5] <= '0;
    end else if (except.timer_int) begin
        registers[0] <= {registers[0][31:13], mode, registers[0][10:8], registers[0][3], registers[0][6:4], 2'b0, registers[0][1:0]};
        registers[3] <= pc;
        registers[4] <= `MMODE_TIMER_INT;
        registers[5] <= '0;
    end else if (except.illegal_inst) begin
        registers[0] <={registers[0][31:13], mode, registers[0][10:8], registers[0][3], registers[0][6:4], 2'b0, registers[0][1:0]};
        registers[3] <= pc;
        registers[4] <= `ILLEGAL_INST;
        registers[5] <= inst;
    end else if (except.mret) begin
        registers[0] <= {registers[0][31:13], `MODE_U, registers[0][10:8], 1'b1, registers[0][6:4], registers[0][7], 1'b0, registers[0][1:0]};
    end else if (csr_we) begin
        unique case(csr_waddr)
        12'h300: registers[0] <= {registers[0][31:13], csr_wdata[12:11], registers[0][10:0]}; // mstatus
        12'h304: registers[7] <= csr_wdata; // mie
        12'h305: registers[1] <= csr_wdata; // mtvec
        12'h340: registers[2] <= csr_wdata; // mscratch
        12'h341: registers[3] <= csr_wdata; // mepc
        12'h342: registers[4] <= csr_wdata; // mcause
        12'h343: registers[5] <= csr_wdata; // mtval
        12'h180: registers[6] <= csr_wdata; // satp
        default: begin end
        endcase
    end

    if (rst) begin
        registers[8] <= '0;
    end else if (clear_mip) begin
        registers[8][7] <= 1'b0;
    end else if (time_int) begin
        registers[8][7] <= 1'b1;
    end

    if (rst) begin 
        mode <= `MODE_M;
    end else if (except.ecall_umode | except.breakpoint | except.timer_int) begin 
        mode <= `MODE_M;
    end else if (except.mret) begin 
        mode <= registers[0][12:11];
    end
end

endmodule
