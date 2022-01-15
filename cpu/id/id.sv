`include "../../defines.svh"

`define INST(_op, _raddr1, _raddr2, _we, _waddr) \
begin \
    op = _op; \
    gpr_raddr1 = _raddr1; \
    gpr_raddr2 = _raddr2; \
    gpr_we = _we; \
    gpr_waddr = _waddr; \
end

`define INST_W(_op, _raddr1, _raddr2, _waddr) `INST(_op, _raddr1, _raddr2, 1'b1, _waddr)
`define INST_R(_op, _raddr1, _raddr2) `INST(_op, _raddr1, _raddr2, 1'b0, 5'b0)

// opcode
`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_JAL    7'b1101111
`define OPCODE_JALR   7'b1100111
`define OPCODE_BRANCH 7'b1100011 // beq, bne, blt, bge, bltu, bgeu
`define OPCODE_LOAD   7'b0000011 // lb, lh, lw, lbu, lhu
`define OPCODE_STORE  7'b0100011 // sb, sh, sw
`define OPCODE_IMM    7'b0010011 // addi, slti, sltiu, xori, ori, andi, slli, srli, srai
`define OPCODE_REG    7'b0110011 // add, sub, sll, slt, sltu, xor, srl, sra, or, and
`define OPCODE_FENCE  7'b0001111 // fence
`define OPCODE_SYSTEM 7'b1110011 // ecall, ebreak, mret, CSRS
`define OPCODE_SIMD   7'b1110111 // add16

// decode comb logic
module decoder (
    input word_t inst,
    // regfile read sigs
    output regaddr_t gpr_raddr1,
    output regaddr_t gpr_raddr2,

    // pipe to ex stage
    output bit_t gpr_we,
    output regaddr_t gpr_waddr,
    output op_t op,
    output word_t imm,
    output logic[4:0] shamt // shift const for slli...
);

word_t utype_imm, jtype_imm, itype_imm, stype_imm, btype_imm, csrtype_imm;
assign utype_imm   = { inst[31:12], 12'b0 };
assign jtype_imm   = { {13{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0 }; // jal
assign itype_imm   = { {21{inst[31]}}, inst[30:20] }; // NOTE: jalr is i-type
assign stype_imm   = { {21{inst[31]}}, inst[30:25], inst[11:7] };
assign btype_imm   = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
assign csrtype_imm = { 27'b0, inst[19:15] };

logic[6:0] opcode;
logic[2:0] funct3;
logic[6:0] funct7;
logic[4:0] funct5;
assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];
assign funct5 = inst[31:27];
assign shamt = inst[24:20];

regaddr_t rs1, rs2, rd;
assign rs1 = inst[19:15];
assign rs2 = inst[24:20];
assign rd  = inst[11:7];

// decoder
always_comb begin
    imm = '0;
    unique case(opcode)
    `OPCODE_LUI: begin
        imm = utype_imm;
        `INST_W(OP_LUI, 5'b0, 5'b0, rd)
    end
    `OPCODE_AUIPC: begin
        imm = utype_imm;
        `INST_W(OP_AUIPC, 5'b0, 5'b0, rd)
    end
    `OPCODE_JAL: begin
        imm = jtype_imm;
        `INST_W(OP_JAL, 5'b0, 5'b0, rd)
    end
    `OPCODE_JALR: begin
        imm = itype_imm;
        `INST_W(OP_JALR, rs1, 5'b0, rd)
    end
    `OPCODE_BRANCH: begin
        imm = btype_imm;
        unique case(funct3)
        3'b000: `INST_R(OP_BEQ, rs1, rs2)
        3'b001: `INST_R(OP_BNE, rs1, rs2)
        3'b100: `INST_R(OP_BLT, rs1, rs2)
        3'b101: `INST_R(OP_BGE, rs1, rs2)
        3'b110: `INST_R(OP_BLTU, rs1, rs2)
        3'b111: `INST_R(OP_BGEU, rs1, rs2)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    `OPCODE_LOAD: begin
        imm = itype_imm;
        unique case(funct3)
        3'b000: `INST_W(OP_LB, rs1, 5'b0, rd)
        3'b001: `INST_W(OP_LH, rs1, 5'b0, rd)
        3'b010: `INST_W(OP_LW, rs1, 5'b0, rd)
        3'b100: `INST_W(OP_LBU, rs1, 5'b0, rd)
        3'b101: `INST_W(OP_LHU, rs1, 5'b0, rd)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    `OPCODE_STORE: begin
        imm = stype_imm;
        unique case(funct3)
        3'b000: `INST_R(OP_SB, rs1, rs2)
        3'b001: `INST_R(OP_SH, rs1, rs2)
        3'b010: `INST_R(OP_SW, rs1, rs2)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    `OPCODE_IMM: begin
        imm = itype_imm;
        unique case(funct3)
        3'b000: `INST_W(OP_ADDI, rs1, 5'b0, rd)
        3'b001: begin
            unique case(funct5)
            5'b00000: `INST_W(OP_SLLI, rs1, 5'b0, rd)
            5'b01100: begin
                unique case(rs2)
                5'b00000: `INST_W(OP_CLZ, rs1, 5'b0, rd)
                5'b00001: `INST_W(OP_CTZ, rs1, 5'b0, rd)
                5'b00010: `INST_W(OP_PCNT, rs1, 5'b0, rd)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)  
                endcase
            end
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b010: `INST_W(OP_SLTI, rs1, 5'b0, rd)
        3'b011: `INST_W(OP_SLTIU, rs1, 5'b0, rd)
        3'b100: `INST_W(OP_XORI, rs1, 5'b0, rd)
        3'b101: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SRLI, rs1, 5'b0, rd)
            7'b0100000: `INST_W(OP_SRAI, rs1, 5'b0, rd)
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b110: `INST_W(OP_ORI, rs1, 5'b0, rd)
        3'b111: `INST_W(OP_ANDI, rs1, 5'b0, rd)
        endcase
    end
    `OPCODE_REG: begin
        unique case(funct3)
        3'b000: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_ADD, rs1, rs2, rd)
            7'b0100000: `INST_W(OP_SUB, rs1, rs2, rd)
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b001: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SLL, rs1, rs2, rd)
            7'b0100100: `INST_W(OP_SBCLR, rs1, rs2, rd)
            7'b0010100: `INST_W(OP_SBSET, rs1, rs2, rd)
            7'b0110100: `INST_W(OP_SBINV, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase 
        end
        3'b010: `INST_W(OP_SLT, rs1, rs2, rd)
        3'b011: `INST_W(OP_SLTU, rs1, rs2, rd)
        3'b100: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_XOR, rs1, rs2, rd)
            7'b0000100: `INST_W(OP_PACK, rs1, rs2, rd)
            7'b0000101: `INST_W(OP_MIN, rs1, rs2, rd)
            7'b0100000: `INST_W(OP_XNOR, rs1, rs2, rd)
            7'b0100100: `INST_W(OP_PACKU, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b101: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SRL, rs1, rs2, rd)
            7'b0000101: `INST_W(OP_MAX, rs1, rs2, rd)
            7'b0100000: `INST_W(OP_SRA, rs1, rs2, rd)
            7'b0100100: `INST_W(OP_SBEXT, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b110: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_OR,  rs1, rs2, rd)
            7'b0000101: `INST_W(OP_MINU, rs1, rs2, rd)
            7'b0100000: `INST_W(OP_ORN, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b111: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_AND,  rs1, rs2, rd)
            7'b0000100: `INST_W(OP_PACKH, rs1, rs2, rd)
            7'b0000101: `INST_W(OP_MAXU, rs1, rs2, rd)
            7'b0100000: `INST_W(OP_ANDN, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        endcase
    end
    `OPCODE_SIMD: begin
        unique case(funct3)
        3'b000: begin
            unique case(funct7)
            7'b0100000: `INST_W(OP_ADD16, rs1, rs2, rd)
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    `OPCODE_FENCE: begin // fence.I, for simplicity, need to flush all ICACHE
        `INST_R(OP_FENCEI, 5'b0, 5'b0)
    end
    `OPCODE_SYSTEM: begin
        imm = csrtype_imm;
        unique case(funct3)
        3'b000: begin
            unique case(funct7)
            7'b0000000: begin
                unique case(rs2)
                5'b00000: `INST_R(OP_ECALL, 5'b0, 5'b0) // ecall
                5'b00001: `INST_R(OP_EBREAK, 5'b0, 5'b0) // ebreak
                5'b00010: `INST_R(OP_URET, 5'b0, 5'b0) // uret
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0001000: begin // sret, wfi
                unique case(rs2)
                5'b00010: `INST_R(OP_SRET, 5'b0, 5'b0) // sret
                5'b00101: `INST_R(OP_WFI, 5'b0, 5'b0) // wfi
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0011000: `INST_R(OP_MRET, 5'b0, 5'b0) // mret, pc <- mepc
            7'b0001001: `INST_R(OP_SFENCE, 5'b0, 5'b0) // sfence.vma
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b001: `INST_W(OP_CSRRW, rs1, 5'b0, rd) // csrrw
        3'b010: `INST_W(OP_CSRRS, rs1, 5'b0, rd) // csrrs
        3'b011: `INST_W(OP_CSRRC, rs1, 5'b0, rd) // csrrc
        3'b100: `INST_R(OP_INVALID, 5'b0, 5'b0)  // hypervisor related insts, not implemented
        3'b101: `INST_W(OP_CSRRWI, 5'b0, 5'b0, rd) // csrrwi
        3'b110: `INST_W(OP_CSRRSI, 5'b0, 5'b0, rd) // csrrsi
        3'b111: `INST_W(OP_CSRRCI, 5'b0, 5'b0, rd) // csrrci
        endcase
    end
    default: `INST_R(OP_INVALID, 5'b0, 5'b0)
    endcase
end

endmodule
