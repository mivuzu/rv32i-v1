module core (
  input 
    clk, 
    state,
  output reg
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
  output reg [31:0]
    rf_rd1,
  // ..led
    instr
);
  parameter MABL=19;
  localparam INIT_ADDR=0;
  
  wire [2:0] instr_stg;
  wire [3:0] cpu_state;
  fsm u0 (
    clk,
    state,
    memctrl_ready,
    instr,
    //
    cede,
    instr_stg,
    cpu_state,
  );

  wire memctrl_ready;
  wire [31:0] rmem;
  mem_controller u1 (
    clk,
    memctrl_en,
    memctrl_cmd,
    rf_pc_in[MABL-1:0],
    temp,
    //
    memctrl_ready,
    rmem,
    // memory specific
    rd,
    we,
    wd,
    ad
  );
  
  wire instr_we,rf_we,rf_pc_we,temp_we,temp_sel,alu_arith,alu_cin,memctrl_en;
  wire [1:0] pc_sel,a_sel,b_sel;
  wire [2:0] wd_sel,format,memctrl_cmd;
  wire [3:0] alu_sel;
  wire [4:0] rf_ra1,rf_ra2,rf_wa;
  datapath_control u2 (
    state,
    memctrl_ready,
    instr_stg,
    cpu_state,
    memmgr_ra1,
    instr,
    temp,
    //
    instr_we,
    rf_we,
    rf_pc_we,
    temp_we,
    temp_sel,
    alu_arith,
    alu_cin,
    memctrl_en,
    pc_sel,
    a_sel,
    b_sel,
    wd_sel,
    format,
    memctrl_cmd,
    alu_sel,
    rf_ra1,
    rf_ra2,
    rf_wa
  );

  wire [31:0] rf_pc_in,rf_pc_out,rf_rd1,rf_rd2,alu_c,instr,temp;
  datapath u3 (
    clk,
    instr_we,
    rf_we,
    rf_pc_we,
    temp_we,
    temp_sel,
    alu_arith,
    alu_cin,
    a_sel,
    b_sel,
    pc_sel,
    wd_sel,
    format,
    alu_sel,
    rf_ra1,
    rf_ra2,
    rf_wa,
    rmem,
    //
    rf_pc_in,
    rf_pc_out,
    rf_rd1,
    rf_rd2,
    alu_c,
    instr,
    temp
  );
  
endmodule
