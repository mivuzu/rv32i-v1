module datapath (
  input
    clk,
    instr_we,
    rf_we,
    rf_pc_we,
    temp_we,
    temp_sel,
    alu_arith,
    alu_cin,
  input [1:0]
    a_sel,
    b_sel,
    pc_sel,
  input [2:0]
    wd_sel,
    format,
  input [3:0]
    alu_sel,
  input [4:0]
    rf_ra1,
    rf_ra2,
    rf_wa,
  input [31:0]
    rmem,
  output reg [31:0]
    rf_pc_in,
    rf_pc_out,
    rf_rd1,
    rf_rd2,
    alu_c,
    instr,
    temp,
  
);
  reg [31:0] instr;
  always @(posedge clk)
    if (instr_we) instr<=rmem;
  
  parameter INIT_ADDR=0;
  reg [31:0] imm;
  always @* begin
    imm=0;
    case (format)
        0: imm={{20{instr[31]}},instr[31:20]}; //I
        1: imm={{20{instr[31]}},instr[31:25],instr[11:7]}; //S
        2: imm={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0}; //B
        3: imm={instr[31:12],12'b0}; //U
        4: imm={{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0}; //J
    endcase
  end

  reg [31:0] rf_pc_in,rf_wd;
  wire [31:0] rf_rd1,rf_rd2,rf_pc_out;
  register_file u2 (
    clk,
    rf_we,
    rf_pc_we,
    rf_ra1,
    rf_ra2,
    rf_wa,
    rf_pc_in,
    rf_wd,
    //
    rf_rd1,
    rf_rd2,
    rf_pc_out
  );

  reg [31:0] pc_next;
  always @* begin
    rf_wd=
      wd_sel[2]?(wd_sel[0]?{31'b0,~alu_flags[2]}:alu_flags[1]):
      wd_sel[1]?
        (wd_sel[0]?temp:pc_next):
        (wd_sel[0]?rmem:alu_c);
    // wd: 000:alu; 001:rmem; 010:pc_next; 011:temp; 1x0:negative 1x1:~carry     
    pc_next=(pc_sel[1]?alu_c:rf_pc_out)+4;
    rf_pc_in=pc_sel[1]?
      (pc_sel[0]?alu_c:pc_next):
      (pc_sel[0]?INIT_ADDR:pc_next);
    // pc_in: 00:pc_out+4; 01:INIT_ADDR; 10:alu+4; 11:alu
  end
  reg [31:0] alu_a,alu_b;
  wire [4:0] alu_flags;
  wire [31:0] alu_c;
  alu u3 (
    alu_cin,
    alu_arith,
    alu_sel,
    alu_a,
    alu_b,
    //
    alu_flags,
    alu_c
  );
  always @* begin
    alu_a=a_sel[1]?temp:(a_sel[0]?rf_pc_out:rf_rd1);
    // 00: rd1; 01: pc; 1x:temp
    alu_b=b_sel[1]?temp:(b_sel[0]?imm:rf_rd2);
    // 00: rd2; 01: imm; 1x:temp;
  end

  always @(posedge clk)
    if (temp_we) temp<=temp_sel?alu_flags:alu_c;
endmodule
