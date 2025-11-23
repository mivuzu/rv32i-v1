module control_unit (
  input
    clk,
    state,
    mem_ready,
  input [4:0]
    alu_flags,
  input [31:0]
    instr,
  output
    cede,
    rf_we,
    pc_we,
    prev_pc_we,
    rs1_we,
    rs2_we,
    alu_we,
    instr_we,
    rst_nar,
    //
    alu_cin,
    alu_arith,
    flagout,
    flagsel,
    mem_ad_sel,
    branch,
  output [1:0]
    a_sel,
    b_sel,
    pc_sel,
    mem_op,
  output [2:0]
    wd_sel,
    format,
  output [3:0]
    alu_sel,
    cpu_state
);

  wire [1:0] alu_op;
  fsm u0_fsm (
    clk,
    state,
    mem_ready,
    branch,
    instr[6:0],
    //
    cede,
    rf_we,
    pc_we,
    prev_pc_we,
    rs1_we,
    rs2_we,
    alu_we,
    instr_we,
    rst_nar,
    ////
    mem_ad_sel,
    a_sel,
    b_sel,
    pc_sel,
    alu_op,
    mem_op,
    wd_sel,
    cpu_state
  );


  alu_dec u1_alu_dec (
    .op(alu_op),
    .funct3(instr[14:12]),
    .op5(instr[5]),
    .funct7(instr[30]),
    .cin(alu_cin),
    .arith(alu_arith),
    .sel(alu_sel),
    .flagout(flagout),
    .flagsel(flagsel)
  );

  wire branch;
  branch_dec u2_branch_dec (
    .funct3(instr[14:12]),
    .alu_flags(alu_flags),
    .branch(branch),
  );
  
  imm_dec u3_imm_dec (
    .op7(instr[6:0]),
    .format(format),
  );


endmodule
