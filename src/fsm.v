module fsm (
  input 
    clk,
    state,
    mem_ready,
    branch,
  input [6:0]
    op7,
  output reg
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
    mem_ad_sel,
  output reg [1:0]
    a_sel,
    b_sel,
    pc_sel,
    alu_op,
    mem_op,
  output reg [2:0]
    wd_sel,
  output reg [3:0]
    cpu_state
);
  
  reg [3:0] cpu_state=0;
  //
  reg [3:0] n_cpu_state;

  always @(posedge clk) begin
    cpu_state<=n_cpu_state;
  end

  localparam S_IDLE=0;
  localparam S_FETCH=1;
  localparam S_DECODE=2;
  localparam S_LUI=3;
  localparam S_AUIPC=4;
  localparam S_JAL=5;
  localparam S_JALR=6;
  localparam S_BRANCH=7;
  localparam S_CMPTAD=8;
  localparam S_LOAD=9;
  localparam S_STORE=10;
  localparam S_RI=11;
  localparam S_RR=12;
  localparam S_CEDE=13;
  localparam S_STILL=14;

  always @* begin
    n_cpu_state=cpu_state;
    case (cpu_state)
      S_IDLE:begin // idle, waiting for init signal
        if (state) begin
           n_cpu_state=S_FETCH;
        end
      end
      S_FETCH:begin // fetch instruction, assume pc is set to the current instruction and give it to mem_ad, compute pc+4, load that to pc and load previous pc to prev_pc
        if (!state) n_cpu_state=S_IDLE;
        else if (mem_ready) n_cpu_state=S_DECODE;
        else n_cpu_state=S_FETCH;
      end
      S_DECODE:begin //decode instruction, load alu input registers and set correct immediate format, compute prev_pc+imm (possibly unstable if the immediate decoder isn't fast enough, remember we are aiming for the alu's fmax) and save to alu_reg, if lui write imm to rd and go back to 1
        case (op7)
          7'b0110111:n_cpu_state=S_LUI;
          7'b0010111:n_cpu_state=S_AUIPC;
          7'b1101111:n_cpu_state=S_JAL;
          7'b1100111:n_cpu_state=S_JALR;
          7'b1100011:n_cpu_state=S_BRANCH;
          7'b0000011:n_cpu_state=S_CMPTAD;
          7'b0100011:n_cpu_state=S_CMPTAD;
          7'b0010011:n_cpu_state=S_RI;
          7'b0110011:n_cpu_state=S_RR;
          7'b0:n_cpu_state=S_CEDE;
          default:n_cpu_state=S_FETCH;
        endcase
      end
      S_LUI:begin // possible to do on S_DECODE and timing safe, not sure why i'm doing this
        n_cpu_state=S_FETCH;
      end
      S_AUIPC:begin // auipc, compute prev_pc+imm and save to rd
        n_cpu_state=S_FETCH;
      end
      S_JAL:begin // jal, compute prev_pc+imm and save to pc, save pc to rd
        n_cpu_state=S_FETCH;
      end
      S_JALR:begin // jalr, compute rs1+imm and save to pc, save pc to rd
        n_cpu_state=S_FETCH;
      end
      S_BRANCH:begin // branch instructions, compute rs1-rs2 and branch (write alu_reg to pc) if a branch signal from another component in the control unit is asserted (said component should receive the instruction and alu flags as inputs),
        n_cpu_state=S_FETCH;
      end
      S_CMPTAD:begin // compute rs1+imm, save to alu_reg
        if (op7[5]) n_cpu_state=S_STORE;
        else n_cpu_state=S_LOAD;
      end
      S_LOAD:begin // memory read, give mem_ad alu_reg, wait for mem_ready, writeback to rd (mem_ready should be set to 1 the cycle mem_rd has the requested data, on memory instructions the alu may be granted to the memory controller to achieve even greater hardware reduction)
        if (mem_ready) n_cpu_state=S_FETCH;
      end
      S_STORE:begin // memory write, give mem_ad alu_reg and mem_wd rs2, wait for mem_ready (mem_ready should be set to 1 the cycle the write ends, i.e if it takes 2 at cycle 2 or if it takes 1 instantly)
        if (mem_ready) n_cpu_state=S_FETCH;
      end
      S_RI:begin // compute register-immediate, save to rd (alu_sel, alu_arith and alu_cin should be computed combinationally from the instruction in this case)
        n_cpu_state=S_FETCH;
      end
      S_RR:begin // compute register-register, save to rd
        n_cpu_state=S_FETCH;
      end
      S_CEDE:begin
        n_cpu_state=S_IDLE;
      end
      S_STILL:n_cpu_state=S_STILL;
      default:;
    endcase
  end

  // output logic
  always @* begin
    cede=0;
    instr_we=0;
    rf_we=0;
    pc_we=0;
    rs1_we=0;
    rs2_we=0;
    alu_we=0;
    prev_pc_we=0;
    rst_nar=0;
    mem_op=2'b00;
    //
    alu_op=2'bxx;
    a_sel=2'bxx;
    b_sel=2'bxx;
    wd_sel=3'bxxx;
    pc_sel=2'bxx;
    mem_ad_sel=1'bx;
    //
    case (cpu_state)
      S_IDLE:begin
        if (state) begin
          pc_sel=1;
          pc_we=1;
          mem_ad_sel=0;
        end
      end
      S_FETCH:begin
        if (mem_ready) begin
          instr_we=1;
          pc_we=1;
        end
        mem_ad_sel=0;
        mem_op=2'b1x;
        //
        a_sel=1; //pc
        b_sel=2; //4
        alu_op=1; // add
        pc_sel=0; //alu
        prev_pc_we=1;
      end
      S_DECODE:begin //decode instruction, load alu input registers and set correct immediate format, compute prev_pc+imm (possibly unstable if the immediate decoder isn't fast enough, remember we are aiming for the alu's fmax) and save to alu_reg, if lui write imm to rd and go back to 1
        rs1_we=1;
        rs2_we=1;
        a_sel=2;
        b_sel=1;
        alu_op=1;
        alu_we=1;
      end
      S_LUI:begin // possible to do on S_DECODE and timing safe, not sure why i'm doing this
        a_sel=3; //0
        b_sel=1; //imm
        alu_op=1; //add
        wd_sel=0;
        rf_we=1;
      end
      S_AUIPC:begin // auipc, compute prev_pc+imm and save to rd
        a_sel=2;
        b_sel=1;
        alu_op=1;
        wd_sel=0;
        rf_we=1;
      end
      S_JAL:begin // jal, compute prev_pc+imm and save to pc, save pc to rd
        a_sel=2;
        b_sel=1;
        alu_op=1;
        pc_sel=0;
        pc_we=1;
        wd_sel=3;
        rf_we=1;
      end
      S_JALR:begin // jalr, compute rs1+imm and save to pc, save pc to rd
        a_sel=0;
        b_sel=1;
        alu_op=1;
        pc_sel=0;
        pc_we=1;
        wd_sel=3;
        rf_we=1;
      end
      S_BRANCH:begin // branch instructions, compute rs1-rs2 and branch (write alu_reg to pc) if a branch signal from another component in the control unit is asserted (said component should receive the instruction and alu flags as inputs),
        if (branch) begin
          pc_sel=2'b10; // alu_reg
          pc_we=1;
        end
        else pc_we=0;
        a_sel=0;
        b_sel=0;
        alu_op=2'b10;
      end
      S_CMPTAD:begin // compute rs1+imm, save to alu_reg
        a_sel=0;
        b_sel=1;
        alu_op=1;
        alu_we=1;
      end
      S_LOAD:begin // memory read, give mem_ad alu_reg, wait for mem_ready, writeback to rd (mem_ready should be set to 1 the cycle mem_rd has the requested data, on memory instructions the alu may be granted to the memory controller to achieve even greater hardware reduction)
        mem_op=1;
        mem_ad_sel=1;
        rf_we=1;
        wd_sel=1;
      end
      S_STORE:begin // memory write, give mem_ad alu_reg and mem_wd rs2, wait for mem_ready (mem_ready should be set to 1 the cycle the write ends, i.e if it takes 2 at cycle 2 or if it takes 1 instantly)
        mem_op=1;
        mem_ad_sel=1;
      end
      S_RI:begin // compute register-immediate, save to rd (alu_sel, alu_arith and alu_cin should be computed combinationally from the instruction in this case)
        a_sel=0;
        b_sel=1;
        alu_op=0;
        wd_sel=0;
        rf_we=1;
      end
      S_RR:begin // compute register-register, save to rd
        a_sel=0;
        b_sel=0;
        alu_op=0;
        wd_sel=0;
        rf_we=1;
      end
      S_CEDE:begin
        cede=1;
      end
      default:;
    endcase
  end
endmodule
