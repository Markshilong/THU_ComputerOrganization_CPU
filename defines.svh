`ifndef DEFINES_SVH
`define DEFINES_SVH

// project configuration
`default_nettype wire
`timescale 1ns / 1ps

typedef logic       bit_t;
typedef logic[7:0]  byte_t;
typedef logic[31:0] word_t;

`define REG_ADDR_WIDTH 5
`define REG_NUM 32
typedef logic[`REG_ADDR_WIDTH-1:0] regaddr_t;

`define CSR_ADDR_WIDTH 12
typedef logic[`CSR_ADDR_WIDTH-1:0] csraddr_t;

`define PC_RESET_VECTOR 32'h8000_0000
`define NOP_INST        { 25'b0, 7'b0010011 }

`define MODE_U 2'b00
`define MODE_S 2'b01
`define MODE_R 2'b10 // reserved
`define MODE_M 2'b11

// ex op
typedef enum {
    OP_NOP,
    // I-logic ops
    OP_ANDI, OP_ORI, OP_XORI, OP_SLLI, OP_SRLI, OP_SRAI,
    // I-arth ops
    OP_ADDI, OP_SLTI, OP_SLTIU,
    // R-logic ops
    OP_AND, OP_OR, OP_XOR, OP_SLL, OP_SRL, OP_SRA, OP_ANDN, OP_ORN, OP_XNOR,
    OP_CLZ, OP_CTZ, OP_PCNT,
    OP_SBSET, OP_SBCLR, OP_SBINV, OP_SBEXT,
    // R-arth ops
    OP_ADD, OP_SUB, OP_SLT, OP_SLTU, OP_MIN, OP_MAX, OP_MINU, OP_MAXU,
    OP_PACK, OP_PACKU, OP_PACKH,
    // SIMD ops
    OP_ADD16,
    // u-type ops
    OP_LUI, OP_AUIPC,
    // j-type ops
    OP_JAL, OP_JALR,
    // b-type ops
    OP_BEQ, OP_BNE, OP_BLT, OP_BLTU, OP_BGE, OP_BGEU,
    // load/store
    OP_LB, OP_LH, OP_LW, OP_LBU, OP_LHU, OP_SB, OP_SH, OP_SW,
    // PRIV ops
    OP_ECALL, OP_EBREAK,
    OP_MRET, OP_SRET, OP_URET, OP_WFI,
    // fence ops
    OP_SFENCE,
    OP_FENCE, OP_FENCEI,
    // csr R/W ops
    OP_CSRRW, OP_CSRRS, OP_CSRRC, OP_CSRRWI, OP_CSRRSI, OP_CSRRCI,
    // INVALID
    OP_INVALID
} op_t;

// exception code in mcause
`define SMODE_SOFT_INT        {1'b1, 31'd1}
`define MMODE_SOFT_INT        {1'b1, 31'd3}
`define SMODE_TIMER_INT       {1'b1, 31'd5}
`define MMODE_TIMER_INT       {1'b1, 31'd7}
`define SMODE_EXT_INT         {1'b1, 31'd9}
`define MMODE_EXT_INT         {1'b1, 31'd11}
`define INST_ADDR_MISALIGNED  32'd0
`define INST_ACCESS_FAULT     32'd1
`define ILLEGAL_INST          32'd2
`define BREAKPOINT            32'd3
`define LOAD_ADDR_MISALIGNED  32'd4
`define LOAD_ACCESS_FAULT     32'd5
`define STORE_ADDR_MISALIGNED 32'd6
`define STORE_ACCESS_FAULT    32'd7
`define ECALL_U               32'd8
`define ECALL_S               32'd9
`define ECALL_M               32'd11
`define INST_PAGE_FAULT       32'd12
`define LOAD_PAGE_FAULT       32'd13
`define STORE_PAGE_FAULT      32'd15

// exception types (interrupts are not included)
typedef struct packed {
  bit_t
    mret, sret, uret,
    inst_misalign, inst_fault, illegal_inst, breakpoint,
    load_misalign, load_fault,
    store_misalign, store_fault,
    ecall_umode, ecall_smode, ecall_mmode,
    inst_pagefault, load_pagefault, store_pagefault,
    timer_int;
} except_t;

// memory access infos
typedef struct packed {
    bit_t load, store;
    logic[3:0] byte_en;
    word_t address, wdata;
} memory_t;

`endif
