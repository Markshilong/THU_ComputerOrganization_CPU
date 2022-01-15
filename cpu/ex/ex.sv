`include "../../defines.svh"

`define WRITE_CSR(_addr) \
begin \
    csr_we = 1'b1; \
    csr_raddr = _addr; \
    csr_waddr = _addr; \
end

module execute (
    // signals from decode stage
    input op_t op,
    input word_t inst,
    input word_t gpr_rdata1,
    input word_t gpr_rdata2,
    input word_t imm,
    input logic[4:0] shamt,
    input word_t pc,
    input word_t csr_rdata,
    input bit_t gpr_we_tmp,
    input except_t except_tmp,
    input bit_t time_int_flag,

    input bit_t ex_btb_branch,
    input word_t ex_btb_target,

    output csraddr_t csr_raddr,
    output csraddr_t csr_waddr,
    output bit_t csr_we,
    output word_t csr_wdata,
    output word_t gpr_wdata,
    output memory_t memory,
    output bit_t gpr_we,
    output except_t except,
    // branch control signals
    output bit_t branch_flag,
    output word_t branch_target,
    output bit_t flush_icache,
    output bit_t update_btb,
    output word_t true_btb_target
);

assign stall_req = 1'b0;

word_t btype_target;
assign btype_target = pc + imm;

// bit operations
word_t onehot_word;
assign onehot_word = (32'b1 << gpr_rdata2[4:0]);
word_t clz_result, ctz_result, cntone_result;
bitcounter bitcounter_instance(
    .value(gpr_rdata1),
    .clz_result(clz_result),
    .ctz_result(ctz_result),
    .cntone_result(cntone_result)
);

bit_t branch_flag_inner;
word_t branch_target_inner;
assign update_btb = branch_flag_inner; // only wirte branch taken
assign true_btb_target = branch_target;
assign branch_flag = (branch_flag_inner ^ ex_btb_branch) || (branch_flag_inner && ex_btb_branch && (ex_btb_target != branch_target_inner));
assign branch_target = branch_flag_inner ? branch_target_inner : pc + 32'h4;

// compare unit
// reg-reg insts
bit_t reg_eq;
assign reg_eq = (gpr_rdata1 == gpr_rdata2);
word_t add_u, sub_u;
bit_t signed_lt, unsigned_lt;
assign add_u = gpr_rdata1 + gpr_rdata2;
assign sub_u = gpr_rdata1 - gpr_rdata2;
assign signed_lt = (gpr_rdata1[31] != gpr_rdata2[31]) ? gpr_rdata1[31] : sub_u[31];
assign unsigned_lt = (gpr_rdata1 < gpr_rdata2);

// simd insts
logic[15:0] add_lo, add_hi;
assign add_lo = gpr_rdata1[15:0] + gpr_rdata2[15:0];
assign add_hi = gpr_rdata1[31:16] + gpr_rdata2[31:16];

// reg-imm insts
word_t addi_u, subi_u;
bit_t signed_lti, unsigned_lti;
assign addi_u = gpr_rdata1 + imm;
assign subi_u = gpr_rdata1 - imm;
assign signed_lti = (gpr_rdata1[31] != imm[31]) ? gpr_rdata1[31] : subi_u[31];
assign unsigned_lti = (gpr_rdata1 < imm);

// control flow: branch and jump
always_comb begin
    unique case(op)
    OP_BEQ:  begin branch_flag_inner = reg_eq;       branch_target_inner = btype_target; end
    OP_BNE:  begin branch_flag_inner = ~reg_eq;      branch_target_inner = btype_target; end
    OP_BLT:  begin branch_flag_inner = signed_lt;    branch_target_inner = btype_target; end
    OP_BGE:  begin branch_flag_inner = ~signed_lt;   branch_target_inner = btype_target; end
    OP_BLTU: begin branch_flag_inner = unsigned_lt;  branch_target_inner = btype_target; end
    OP_BGEU: begin branch_flag_inner = ~unsigned_lt; branch_target_inner = btype_target; end
    OP_JAL:  begin branch_flag_inner = 1'b1;         branch_target_inner = btype_target; end
    OP_JALR: begin branch_flag_inner = 1'b1;         branch_target_inner = addi_u;       end
    OP_MRET: begin branch_flag_inner = 1'b1;         branch_target_inner = csr_rdata;    end
    default: begin branch_flag_inner = 1'b0;         branch_target_inner = '0;           end
    endcase
end

assign flush_icache = (op == OP_FENCEI) || (op == OP_FENCE);

// alu
word_t alu_result;
assign gpr_wdata = alu_result;
word_t pc_plus4;
assign pc_plus4 = { pc[31:2] + 30'd1, 2'b0 };
always_comb begin: alu
    unique case(op)
    OP_ANDI: alu_result = gpr_rdata1 & imm;
    OP_ORI:  alu_result = gpr_rdata1 | imm;
    OP_XORI: alu_result = gpr_rdata1 ^ imm;
    OP_SLLI: alu_result = gpr_rdata1 << shamt;
    OP_SRLI: alu_result = gpr_rdata1 >> shamt;
    OP_SRAI: alu_result = $signed(gpr_rdata1) >>> shamt;
    OP_ADDI: alu_result = addi_u;
    OP_SLTI: alu_result = { 31'b0, signed_lti };
    OP_SLTIU:alu_result = { 31'b0, unsigned_lti };
    OP_AND:  alu_result = gpr_rdata1 & gpr_rdata2;
    OP_ANDN: alu_result = gpr_rdata1 & (~gpr_rdata2);
    OP_OR:   alu_result = gpr_rdata1 | gpr_rdata2;
    OP_ORN:  alu_result = gpr_rdata1 | (~gpr_rdata2);
    OP_XOR:  alu_result = gpr_rdata1 ^ gpr_rdata2;
    OP_XNOR: alu_result = gpr_rdata1 ^ (~gpr_rdata2);
    OP_SLL:  alu_result = gpr_rdata1 << gpr_rdata2[4:0];
    OP_SRL:  alu_result = gpr_rdata1 >> gpr_rdata2[4:0];
    OP_SRA:  alu_result = $signed(gpr_rdata1) >>> gpr_rdata2[4:0];
    OP_PACK: alu_result = { gpr_rdata2[15:0], gpr_rdata1[15:0] };
    OP_PACKU:alu_result = { gpr_rdata2[31:16], gpr_rdata1[31:16] };
    OP_PACKH:alu_result = { 16'b0, gpr_rdata2[7:0], gpr_rdata1[7:0] };
    OP_SBSET:alu_result = gpr_rdata1 | onehot_word;
    OP_SBCLR:alu_result = gpr_rdata1 & (~onehot_word);
    OP_SBINV:alu_result = gpr_rdata1 ^ onehot_word;
    OP_SBEXT:alu_result = 32'b1 & (gpr_rdata1 >> gpr_rdata2[4:0]);
    OP_CLZ:  alu_result = clz_result;
    OP_CTZ:  alu_result = ctz_result;
    OP_PCNT: alu_result = cntone_result;
    OP_ADD:  alu_result = add_u;
    OP_SUB:  alu_result = sub_u;
    OP_MIN:  alu_result = signed_lt ? gpr_rdata1 : gpr_rdata2;
    OP_MAX:  alu_result = signed_lt ? gpr_rdata2 : gpr_rdata1;
    OP_MINU: alu_result = unsigned_lt ? gpr_rdata1 : gpr_rdata2;
    OP_MAXU: alu_result = unsigned_lt ? gpr_rdata2 : gpr_rdata1;
    OP_SLT:  alu_result = { 31'b0, signed_lt };
    OP_SLTU: alu_result = { 31'b0, unsigned_lt };
    OP_ADD16: alu_result = { add_hi, add_lo };
    OP_LUI:  alu_result = imm;
    OP_AUIPC:alu_result = btype_target;
    OP_JAL:  alu_result = pc_plus4;
    OP_JALR: alu_result = pc_plus4;
    OP_CSRRW, OP_CSRRS, OP_CSRRC,
    OP_CSRRWI, OP_CSRRSI, OP_CSRRCI:  alu_result = csr_rdata;
    default: alu_result = '0;
    endcase
end

// memory access
always_comb begin
    memory = '0;
    memory.address = addi_u;
    memory.wdata = '0;
    unique case(op)
    OP_LB, OP_LH, OP_LW, OP_LBU, OP_LHU: memory.load = 1'b1;
    OP_SB, OP_SH, OP_SW: memory.store = 1'b1;
    default: begin end
    endcase

    unique case(op)
    OP_LB, OP_SB, OP_LBU: memory.byte_en = 4'b0001 << addi_u[1:0];
    OP_LH, OP_SH, OP_LHU: memory.byte_en = addi_u[1] ? 4'b1100 : 4'b0011;
    OP_LW, OP_SW: memory.byte_en = 4'b1111;
    default: memory.byte_en = 4'b0000;
    endcase

    unique case(op)
    OP_SB: begin
        unique case(addi_u[1:0])
        2'b00: memory.wdata = { 24'b0, gpr_rdata2[7:0] };
        2'b01: memory.wdata = { 16'b0, gpr_rdata2[7:0], 8'b0 };
        2'b10: memory.wdata = { 8'b0, gpr_rdata2[7:0], 16'b0 };
        2'b11: memory.wdata = { gpr_rdata2[7:0], 24'b0 };
        endcase
    end 
    OP_SH: memory.wdata = addi_u[1] ? { gpr_rdata2[15:0], 16'b0 } : { 16'b0, gpr_rdata2[15:0] };
    OP_SW: memory.wdata = gpr_rdata2;
    default: begin end
    endcase

    if (|except) begin 
        memory.store = 1'b0;
        memory.load = 1'b0;
    end
end

// CSR read/write control
always_comb begin
    unique case(op)
    OP_CSRRW, OP_CSRRS, OP_CSRRC, 
    OP_CSRRWI, OP_CSRRSI, OP_CSRRCI:
        `WRITE_CSR(inst[31:20])
    OP_MRET: begin
        csr_we = 1'b0;
        csr_raddr = 12'h341;
        csr_waddr = '0;
    end
    default: begin
        csr_we = 1'b0;
        csr_raddr = '0;
        csr_waddr = '0;
    end
    endcase
end
// CSR write data
always_comb begin
    unique case(op)
    OP_CSRRW:  csr_wdata = gpr_rdata1;
    OP_CSRRS:  csr_wdata = (csr_rdata | gpr_rdata1);
    OP_CSRRC:  csr_wdata = (csr_rdata & ~gpr_rdata1);
    OP_CSRRWI: csr_wdata = imm;
    OP_CSRRSI: csr_wdata = (csr_rdata | imm);
    OP_CSRRCI: csr_wdata = (csr_rdata & ~imm);
    default:   csr_wdata = csr_rdata;
    endcase
end

assign gpr_we = (|except) ? 1'b0 : gpr_we_tmp;
// exception check unit
always_comb begin
    except = except_tmp;
    unique case(op)
    OP_MRET:   except.mret = 1'b1;
    OP_ECALL:  except.ecall_umode = 1'b1;
    OP_EBREAK: except.breakpoint = 1'b1;
    default: begin end
    endcase

    if (time_int_flag) except.timer_int = 1'b1;
    except.illegal_inst = (op == OP_INVALID);
end

endmodule

