module core (
  input 
    clk, 
    state,
  output
    cede,
  //memory specific
  input [7:0] 
    rd,
  output
    we,
  output [7:0]
    wd,
  output [MABL-1:0] 
    ad,
  //memmgr access
  input [4:0]
    memmgr_ra1,
  output [31:0]
    rd1,
  // led/debugging
    instr,
  output [3:0]
    cpu_state
);
  parameter MABL=19;
  localparam INIT_ADDR=0;

  wire mem_ready;
  wire [31:0] mem_rd;
  mem_controller u1 (
    clk,
    instr[5],
    instr[14:12],
    mem_op,
    mem_ad[MABL-1:0],
    rs2_reg,
    //
    mem_ready,
    mem_rd,
    // memory specific
    rd,
    we,
    wd,
    ad,
  );

  wire
    rf_we,
    pc_we,
    prev_pc_we,
    rs1_we,
    rs2_we,
    alu_we,
    instr_we,
    rst_nar,
    alu_cin,
    alu_arith,
    flagout,
    flagsel,
    mem_ad_sel,
    branch;
  wire [1:0] 
    a_sel,
    b_sel,
    pc_sel,
    mem_op;
  wire [2:0]
    wd_sel,
    format;
  wire [3:0]
    alu_sel,
    cpu_state;
  control_unit u2 (
    clk,
    state,
    mem_ready,
    alu_flags,
    instr,
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
    alu_cin,
    alu_arith,
    flagout,
    flagsel,
    mem_ad_sel,
    branch,
    a_sel,
    b_sel,
    pc_sel,
    mem_op,
    wd_sel,
    format,
    alu_sel,
    cpu_state
  );

  wire [4:0] alu_flags;
  wire [31:0] mem_ad,rs2_reg;
  datapath u3 (
    clk,
    state,
    instr_we,
    rf_we,
    pc_we,
    rs1_we,
    rs2_we,
    alu_we,
    prev_pc_we,
    rst_nar,
    alu_arith,
    alu_cin,
    flagout,
    flagsel,
    mem_ad_sel,
    branch,
    a_sel,
    b_sel,
    pc_sel,
    wd_sel,
    format,
    alu_sel,
    mem_rd,
    //
    alu_flags,
    instr,
    rs2_reg,
    mem_ad,
    //
    memmgr_ra1,
    rd1,
  );
  
endmodule
