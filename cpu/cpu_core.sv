`include "../defines.svh"

module cpu (
    input clk, rst,

    output word_t if_address,
    output bit_t if_load,
    output bit_t trap_flag,
    output word_t trap_target,
    input word_t if_rdata,
    input bit_t ibus_stall_req,

    output word_t mem_address,
    output bit_t mem_load,
    output bit_t mem_store,
    output word_t mem_wdata,
    output logic[3:0] mem_byte_en,
    input word_t mem_rdata,
    input bit_t mem_stall_req,

    input bit_t time_int,
    input bit_t clear_mip
);

bit_t time_int_flag;

csraddr_t ex_csr_raddr;
word_t ex_csr_rdata;
csraddr_t ex_csr_waddr;
bit_t ex_csr_we;
word_t ex_csr_wdata;

csraddr_t mem_csr_waddr;
bit_t mem_csr_we;
word_t mem_csr_rdata;
word_t mem_csr_wdata;
except_t mem_except;
word_t mem_pc;
op_t mem_op;
word_t mem_inst;
except_t mem_except_tmp;
word_t mem_gpr_wdata_tmp;

csr_regs csr_regs(
    .clk(clk),
    .rst(rst),
    .inst(mem_inst),
    // read at ex stage
    .csr_raddr(ex_csr_raddr),
    .csr_rdata(ex_csr_rdata),
    // write at mem stage
    .csr_waddr(mem_csr_waddr),
    .csr_we(mem_csr_we),
    .csr_wdata(mem_csr_wdata),
    // except
    .pc(mem_pc),
    .except(mem_except),
    .trap_flag(trap_flag),
    .trap_target(trap_target),
    .time_int_flag(time_int_flag),
    .time_int(time_int),
    .clear_mip(clear_mip)
);

bit_t wb_gpr_we;
regaddr_t wb_gpr_waddr;
word_t wb_gpr_wdata;
regaddr_t id_gpr_raddr1;
word_t id_gpr_rdata1;
regaddr_t id_gpr_raddr2;
word_t id_gpr_rdata2;

regfile regfile(
    .clk(clk),
    .rst(rst),
    // write at wb stage
    .gpr_we(wb_gpr_we),
    .gpr_waddr(wb_gpr_waddr),
    .gpr_wdata(wb_gpr_wdata),
    // read at id stage
    .gpr_raddr1(id_gpr_raddr1),
    .gpr_rdata1(id_gpr_rdata1),
    .gpr_raddr2(id_gpr_raddr2),
    .gpr_rdata2(id_gpr_rdata2)
);

bit_t id_stall_req, if_stall_req;
bit_t stall_pc, stall_if, stall_id, stall_ex, stall_mem, stall_wb;
stall_ctrl stall_ctrl(
    .if_stall_req(if_stall_req),
    .id_stall_req(id_stall_req),
    .mem_stall_req(mem_stall_req),

    .stall_pc(stall_pc),
    .stall_if(stall_if),
    .stall_id(stall_id),
    .stall_ex(stall_ex),
    .stall_mem(stall_mem),
    .stall_wb(stall_wb)
);

bit_t branch_flag;
word_t branch_target;

word_t if_pc;
except_t if_except;

bit_t flush_icache;
word_t if_inst;

bit_t update_btb;
word_t true_btb_target;

bit_t if_predict_branch;
word_t if_predict_target;
word_t ex_pc;

fetch pipeline_pc(
    .clk(clk),
    .rst(rst),

    .stall(stall_pc),
    .ibus_stall(ibus_stall_req),
    .backend_stall(id_stall_req | mem_stall_req),
    .branch_flag(branch_flag),
    .branch_target(branch_target),
    .trap_flag(trap_flag),
    .trap_target(trap_target),

    .flush_icache(flush_icache),

    // update btb
    .ex_pc(ex_pc),
    .update_btb(update_btb),
    .true_btb_target(true_btb_target),

    .pc(if_pc),
    .inst(if_inst),
    .predict_branch(if_predict_branch),
    .predict_branch_target(if_predict_target),
    .icache_except(if_except),
    .if_stall_req(if_stall_req),
    
    .ibus_inst(if_rdata),
    .if_address(if_address),
    .if_load(if_load)
);

word_t id_pc;
word_t id_inst;
except_t id_except;
bit_t id_btb_branch;
word_t id_btb_target;

if_id pipeline_if_id(
    .clk(clk),
    .rst(rst),

    .stall_if(stall_if),
    .stall_id(stall_id),
    .trap(trap_flag),
    .branch_flag(branch_flag),
    
    .if_except(if_except),
    .if_pc(if_pc),
    .if_inst(if_inst),
    .if_btb_branch(if_predict_branch),
    .if_btb_target(if_predict_target),
    
    .id_except(id_except),
    .id_pc(id_pc),
    .id_inst(id_inst),
    .id_btb_branch(id_btb_branch),
    .id_btb_target(id_btb_target)
);

word_t true_gpr_rdata1, true_gpr_rdata2;
bit_t ex_gpr_we, ex_gpr_we_tmp, mem_gpr_we;
regaddr_t ex_gpr_waddr, mem_gpr_waddr;
word_t ex_gpr_wdata, mem_gpr_wdata;
memory_t ex_memory, mem_memory;

forward_unit forward_unit(
    .raddr1(id_gpr_raddr1),
    .raddr2(id_gpr_raddr2),
    
    .ex_gpr_we(ex_gpr_we),
    .ex_gpr_waddr(ex_gpr_waddr),
    .ex_gpr_wdata(ex_gpr_wdata),
    .ex_memory_load(ex_memory.load),
    
    .mem_gpr_we(mem_gpr_we),
    .mem_gpr_waddr(mem_gpr_waddr),
    .mem_gpr_wdata(mem_gpr_wdata),
    .mem_memory_load(mem_memory.load),
    
    .gpr_rdata1(id_gpr_rdata1),
    .gpr_rdata2(id_gpr_rdata2),

    .true_gpr_rdata1(true_gpr_rdata1),
    .true_gpr_rdata2(true_gpr_rdata2),
    .id_stall_req(id_stall_req)
);

bit_t id_gpr_we;
regaddr_t id_gpr_waddr;
op_t id_op, ex_op;
word_t id_imm, ex_imm;
logic[4:0] id_shamt, ex_shamt;
word_t ex_inst;
except_t ex_except_tmp, ex_except;
word_t ex_gpr_rdata1, ex_gpr_rdata2;


decoder decoder(
    .inst(id_inst),
    
    .gpr_raddr1(id_gpr_raddr1),
    .gpr_raddr2(id_gpr_raddr2),
    
    .gpr_we(id_gpr_we),
    .gpr_waddr(id_gpr_waddr),
    .op(id_op),
    .imm(id_imm),
    .shamt(id_shamt)
);

bit_t ex_btb_branch;
word_t ex_btb_target;
id_ex pipeline_id_ex(
    .clk(clk),
    .rst(rst),

    .stall_id(stall_id),
    .stall_ex(stall_ex),
    .trap(trap_flag),
    .branch_flag(branch_flag),
    
    .id_pc(id_pc),
    .id_inst(id_inst),
    .id_except(id_except),
    .id_gpr_we(id_gpr_we),
    .id_gpr_waddr(id_gpr_waddr),
    .id_op(id_op),
    .id_imm(id_imm),
    .id_shamt(id_shamt),
    .id_gpr_rdata1(true_gpr_rdata1),
    .id_gpr_rdata2(true_gpr_rdata2),
    .id_btb_branch(id_btb_branch),
    .id_btb_target(id_btb_target),
    
    .ex_pc(ex_pc),
    .ex_inst(ex_inst),
    .ex_except(ex_except_tmp),
    .ex_gpr_we(ex_gpr_we_tmp),
    .ex_gpr_waddr(ex_gpr_waddr),
    .ex_op(ex_op),
    .ex_imm(ex_imm),
    .ex_shamt(ex_shamt),
    .ex_gpr_rdata1(ex_gpr_rdata1),
    .ex_gpr_rdata2(ex_gpr_rdata2),
    .ex_btb_branch(ex_btb_branch),
    .ex_btb_target(ex_btb_target)
);

execute executer(
    .op(ex_op),
    .inst(ex_inst),
    .gpr_rdata1(ex_gpr_rdata1),
    .gpr_rdata2(ex_gpr_rdata2),
    .imm(ex_imm),
    .shamt(ex_shamt),
    .pc(ex_pc),
    .csr_rdata(ex_csr_rdata),
    .gpr_we_tmp(ex_gpr_we_tmp),
    .except_tmp(ex_except_tmp),
    .time_int_flag(time_int_flag),

    .ex_btb_branch(ex_btb_branch),
    .ex_btb_target(ex_btb_target),
    
    .csr_raddr(ex_csr_raddr),
    .csr_waddr(ex_csr_waddr),
    .csr_we(ex_csr_we),
    .csr_wdata(ex_csr_wdata),
    .gpr_wdata(ex_gpr_wdata),
    .memory(ex_memory),
    .gpr_we(ex_gpr_we),
    .except(ex_except),

    .branch_flag(branch_flag),
    .branch_target(branch_target),
    .flush_icache(flush_icache),
    .update_btb(update_btb),
    .true_btb_target(true_btb_target)
);

ex_mem pipeline_ex_mem(
    .clk(clk),
    .rst(rst),
    
    .stall_ex(stall_ex),
    .stall_mem(stall_mem),
    .trap(trap_flag),
    
    .ex_op(ex_op),
    .ex_inst(ex_inst),
    .ex_except(ex_except),
    .ex_gpr_we(ex_gpr_we),
    .ex_gpr_waddr(ex_gpr_waddr),
    .ex_gpr_wdata(ex_gpr_wdata),
    .ex_memory(ex_memory),
    .ex_csr_waddr(ex_csr_waddr),
    .ex_csr_we(ex_csr_we),
    .ex_csr_wdata(ex_csr_wdata),
    .ex_pc(ex_pc),
    
    .mem_op(mem_op),
    .mem_inst(mem_inst),
    .mem_except(mem_except_tmp),
    .mem_gpr_we(mem_gpr_we),
    .mem_gpr_waddr(mem_gpr_waddr),
    .mem_gpr_wdata(mem_gpr_wdata_tmp),
    .mem_memory(mem_memory),
    .mem_csr_waddr(mem_csr_waddr),
    .mem_csr_we(mem_csr_we),
    .mem_csr_wdata(mem_csr_wdata),
    .mem_pc(mem_pc)
);

mem mem (
    .op(mem_op),
    .memory(mem_memory),
    .gpr_wdata_tmp(mem_gpr_wdata_tmp),
    .except_tmp(mem_except_tmp),
    
    .gpr_wdata(mem_gpr_wdata),
    .mem_except(mem_except),

    .mem_address(mem_address),
    .mem_load(mem_load),
    .mem_store(mem_store),
    .mem_wdata(mem_wdata),
    .mem_byte_en(mem_byte_en),
    .mem_rdata(mem_rdata)
);

mem_wb pipeline_mem_wb(
    .clk(clk),
    .rst(rst),

    .stall_mem(stall_mem),
    .stall_wb(stall_wb),
    
    .mem_gpr_waddr(mem_gpr_waddr),
    .mem_gpr_wdata(mem_gpr_wdata),
    .mem_gpr_we(mem_gpr_we),
    
    .wb_gpr_waddr(wb_gpr_waddr),
    .wb_gpr_wdata(wb_gpr_wdata),
    .wb_gpr_we(wb_gpr_we)
);

endmodule

