module fsm (
  input 
    clk,
    state,
  input [31:0]
    rf_pc_in,
    temp,
  output reg
    cede,
  output reg [2:0]
    instr_stg,
  output reg [3:0]
    cpu_state,
  //
  input [7:0]
    rd,
  output reg
    we,
  output reg [7:0]
    wd,
  output reg [MABL-1:0]
    ad,
  output reg [31:0]
    instr,
    rmem
);
  parameter MABL=19;
  localparam INIT_ADDR=0;
  
  reg [2:0] r_stg=0,instr_stg=0;
  reg [3:0] cpu_state=0;
  reg [7:0] wd;
  reg [MABL-1:0] ad,n_ad;
  reg [31:0] instr=0,rmem=0;
  //
  reg instr_we,cede,rmem_rst,rmem_we,we;
  reg [1:0] sel_ad,sel_instr,sel_rmem,sel_wd;
  reg [2:0] n_r_stg,n_instr_stg;
  reg [3:0] n_cpu_state;
  
  always @* begin
    n_ad=sel_ad[1]?
      (sel_ad[0]?ad:rf_pc_in):
      (sel_ad[0]?ad+1:INIT_ADDR);
    // 00:INIT_ADDR 01:ad+1 10:rf_pc_in 11:ad
    wd=sel_wd[1]?
      (sel_wd[0]?temp[31:24]:temp[23:16]):
      (sel_wd[0]?temp[15:8]:temp[7:0]);
  end
  always @(posedge clk) begin
    cpu_state<=n_cpu_state;
    instr_stg<=n_instr_stg;
    r_stg<=n_r_stg;
    ad<=n_ad;
    if (instr_we) 
      if (sel_instr==0) instr[7:0]<=rd;
      else if (sel_instr==1) instr[15:8]<=rd;
      else if (sel_instr==2) instr[23:16]<=rd;
      else if (sel_instr==3) instr[31:24]<=rd;
    if (rmem_rst) rmem<=0;
    else if (rmem_we)
      if (sel_rmem==0) rmem[7:0]<=rd;
      else if (sel_rmem==1) rmem[15:8]<=rd;
      else if (sel_rmem==2) rmem[23:16]<=rd;
      else if (sel_rmem==3) rmem[31:24]<=rd;
  end
  
  always @* begin
    n_cpu_state=cpu_state;
    n_instr_stg=instr_stg;
    n_r_stg=r_stg;
    sel_ad=2'b11;
    sel_instr=2'b00;
    sel_rmem=2'b00;
    rmem_we = 1'b0;
    rmem_rst= 1'b0;
    instr_we=0;
    cede=0;
    we=0;
    sel_wd=0;
    case (state)
      0:begin
        n_cpu_state=0;
        n_instr_stg=0;
        n_r_stg=0;
      end
      1:case (cpu_state)
        0:begin
          n_cpu_state=1;
          sel_ad=0;
        end
        1:case (r_stg)
          0:begin
            n_r_stg=1;
            sel_ad=1;
          end
          1:begin
            n_r_stg=2;
            sel_ad=1;
            instr_we=1;
            sel_instr=0;
          end
          2:begin
            n_r_stg=3;
            sel_ad=1;
            instr_we=1;
            sel_instr=1;
          end
          3:begin
            n_r_stg=4;
            sel_ad=1;
            instr_we=1;
            sel_instr=2;
          end
          4:begin
            n_r_stg=0;
            n_cpu_state=2;
            instr_we=1;
            sel_instr=3;
          end
        endcase
        //2: begin
        //end
        ///*
        2:
        case (instr[6:0])
          7'b1100111:case (instr_stg) //jalr
            0:n_instr_stg=1;
            1:n_instr_stg=2;
            2:begin
              n_instr_stg=0;
              n_cpu_state=1;
              sel_ad=2;
            end
          endcase
          //
          7'b1100011:case (instr[14:12])
            default:case (instr_stg) //all branch instructions
              0:n_instr_stg=1; //load flags to temp
              1:begin //set new pc accordingly
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          //
          7'b0000011:case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: n_instr_stg=5; // load to rd
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: n_instr_stg=6; // load to rd
              6: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load first byte and increment again
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
                sel_ad=1;
              end
              4:begin //load second byte and increment again
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
                sel_ad=1;
              end
              5:begin //load third byte
                rmem_we=1;
                sel_rmem=2;
                n_instr_stg=6;
              end
              6:begin //load last byte
                rmem_we=1;
                sel_rmem=3;
                n_instr_stg=7;
              end
              7: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store
                we=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //sh
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte and increment
                we=1;
                n_instr_stg=3;
                sel_ad=1;
              end
              3:begin //store second byte
                we=1;
                sel_wd=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte
                we=1;
                n_instr_stg=3;
                sel_ad=1;
              end
              3:begin //store second byte
                we=1;
                sel_wd=1;
                n_instr_stg=4;
                sel_ad=1;
              end
              4:begin //store third byte
                we=1;
                sel_wd=2;
                n_instr_stg=5;
                sel_ad=1;
              end
              5:begin //store last byte
                we=1;
                sel_wd=3;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          7'b0:begin
            cede=1;
          end
          default:begin // unspecified instructions are assumed to take 1 cycle
            n_cpu_state=1;
            sel_ad=2;
          end
        endcase
      endcase
    endcase
  end    
endmodule
/*
module nstate (
  input main_state,
  input [2:0] instr_stg,
              r_stg,
  input [3:0] cpu_state,
  input [31:0] instr,
  output reg rmem_we,
             rmem_rst,
             instr_we,
             we,
             cede,
  output reg [1:0] sel_ad,
                   sel_instr,
                   sel_rmem,
                   sel_wd,
  output reg [2:0] n_instr_stg,
                   n_r_stg,
  output reg [3:0] n_cpu_state,
);
  always @* begin
    n_cpu_state=cpu_state;
    n_instr_stg=instr_stg;
    n_r_stg=r_stg;
    sel_ad=2'b11;
    sel_instr=2'b00;
    sel_rmem=2'b00;
    rmem_we = 1'b0;
    rmem_rst= 1'b0;
    instr_we=0;
    cede=0;
    we=0;
    sel_wd=0;
    case (state)
      0:begin
        n_cpu_state=0;
        n_instr_stg=0;
        n_r_stg=0;
      end
      1:case (cpu_state)
        0:begin
          n_cpu_state=1;
          sel_ad=0;
        end
        1:case (r_stg)
          0:begin
            n_r_stg=1;
            sel_ad=1;
          end
          1:begin
            n_r_stg=2;
            sel_ad=1;
            instr_we=1;
            sel_instr=0;
          end
          2:begin
            n_r_stg=3;
            sel_ad=1;
            instr_we=1;
            sel_instr=1;
          end
          3:begin
            n_r_stg=4;
            sel_ad=1;
            instr_we=1;
            sel_instr=2;
          end
          4:begin
            n_r_stg=0;
            n_cpu_state=2;
            instr_we=1;
            sel_instr=3;
          end
        endcase
        //2: begin
        //end
        ///*
        2:
        case (instr[6:0])
          7'b1100111:case (instr_stg) //jalr
            0:n_instr_stg=1;
            1:n_instr_stg=2;
            2:begin
              n_instr_stg=0;
              n_cpu_state=1;
              sel_ad=2;
            end
          endcase
          //
          7'b1100011:case (instr[14:12])
            default:case (instr_stg) //all branch instructions
              0:n_instr_stg=1; //load flags to temp
              1:begin //set new pc accordingly
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          //
          7'b0000011:case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: n_instr_stg=5; // load to rd
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: n_instr_stg=6; // load to rd
              6: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_ad=1;
                n_instr_stg=3;
              end
              3:begin //load first byte and increment again
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
                sel_ad=1;
              end
              4:begin //load second byte and increment again
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
                sel_ad=1;
              end
              5:begin //load third byte
                rmem_we=1;
                sel_rmem=2;
                n_instr_stg=6;
              end
              6:begin //load last byte
                rmem_we=1;
                sel_rmem=3;
                n_instr_stg=7;
              end
              7: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store
                we=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //sh
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte and increment
                we=1;
                n_instr_stg=3;
                sel_ad=1;
              end
              3:begin //store second byte
                we=1;
                sel_wd=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte
                we=1;
                n_instr_stg=3;
                sel_ad=1;
              end
              3:begin //store second byte
                we=1;
                sel_wd=1;
                n_instr_stg=4;
                sel_ad=1;
              end
              4:begin //store third byte
                we=1;
                sel_wd=2;
                n_instr_stg=5;
                sel_ad=1;
              end
              5:begin //store last byte
                we=1;
                sel_wd=3;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_ad=2;
              end
            endcase
          endcase
          7'b0:begin
            cede=1;
          end
          default:begin // unspecified instructions are assumed to take 1 cycle
            n_cpu_state=1;
            sel_ad=2;
          end
        endcase
      endcase
    endcase
  end    
endmodule 
//*/
