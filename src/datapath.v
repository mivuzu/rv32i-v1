module datapath (
  input
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
    //
    alu_arith,
    alu_cin,
    flagout,
    flagsel,
    mem_ad_sel,
    branch,
  input [1:0]
    a_sel,
    b_sel,
    pc_sel,
  input [2:0]
    wd_sel,
    format,
  input [3:0]
    alu_sel,
  input [31:0]
    mem_rd,
  output [4:0]
    alu_flags,
  //
  output reg [31:0]
    instr,
    rs2_reg,
    mem_ad,
  ////
  input [4:0] memmgr_ra1,
  output [31:0] rf_rd1,
  
);
  parameter INIT_ADDR=0;

  reg [31:0] instr;
  always @(posedge clk)
    if (instr_we) instr<=mem_rd;

  reg [31:0] mem_ad;
  always @*
    mem_ad=mem_ad_sel?alu_reg:pc;

  reg [31:0] imm;
  always @* begin
    //imm=0;
    //case (format)
    //    0: imm={{20{instr[31]}},instr[31:20]}; //I
    //    1: imm={{20{instr[31]}},instr[31:25],instr[11:7]}; //S
    //    2: imm={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0}; //B
    //    3: imm={instr[31:12],12'b0}; //U
    //    4: imm={{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0}; //J
    //    default:;
    //endcase
    imm=
      format[2]?
        ({{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0}): // J
        (format[1]?
          (format[0]?
            ({(instr[31:12]),12'b0}): // U
            ({{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0}) // B
          ):
          (format[0]?
            ({{20{instr[31]}},instr[31:25],instr[11:7]}): // S
            ({{20{instr[31]}},instr[31:20]}) // I
          )
    );
    // 0:I 1:S 2:B 3:U 4-7:J
  end

  reg [31:0] pc_in,rf_wd;
  wire [31:0] rf_rd1,rf_rd2,pc;
  register_file u2 (
    .clk(clk),
    .we(rf_we),
    .pc_we(pc_we),
    .ra1(state?instr[19:15]:memmgr_ra1),
    .ra2(instr[24:20]),
    .wa(instr[11:7]),
    .pc_in(pc_in),
    .wd(rf_wd),
    //
    .rd1(rf_rd1),
    .rd2(rf_rd2),
    .pc_out(pc)
  );
  always @* begin
    rf_wd=
      flagout?(flagsel[0]?{31'b0,~alu_flags[2]}:{31'b0,alu_flags[1]}):
      wd_sel[1]?
        (wd_sel[0]?pc:alu_reg):
        (wd_sel[0]?mem_rd:alu_c);
    // wd: 000:alu; 001:mem_rd; 010:alu_reg; 011: pc; 1x0:negative 1x1:~carry     
    pc_in=pc_sel[1]?alu_reg:(pc_sel[0]?INIT_ADDR:alu_c);
    // pc_in: 0:alu; 1:INIT_ADDR;
  end
  
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
  reg [31:0] alu_a,alu_b;
  always @* begin
    alu_a=a_sel[1]?(a_sel[0]?0:prev_pc):(a_sel[0]?pc:rs1_reg);
    // 00: rd1_reg; 01: pc ; 10:prev_pc 11:0
    alu_b=b_sel[1]?32'd4:(b_sel[0]?imm:rs2_reg);
    // 00: rd2_reg; 01: imm; 1x:4;
  end

  // non architectural registers
  wire rs1_we,rs2_we,alu_we,prev_pc_we;
  reg [31:0] rs1_reg,rs2_reg,alu_reg,prev_pc;
  always @(posedge clk) begin
  if (rst_nar) begin
    rs1_reg<=0;
    rs2_reg<=0;
    alu_reg<=0;
    prev_pc<=0;
  end
  else begin
    if (rs1_we) rs1_reg<=rf_rd1;
    if (rs2_we) rs2_reg<=rf_rd2;
    if (alu_we) alu_reg<=alu_c;
    if (prev_pc_we) prev_pc<=pc;
  end
  end
endmodule
