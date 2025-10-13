module fsm (
  input 
    clk,
    state,
    memctrl_ready,
  input [31:0]
    instr,
  output reg
    cede,
  output reg [2:0]
    instr_stg,
  output reg [3:0]
    cpu_state,
);
  
  reg [2:0] instr_stg=0;
  reg [3:0] cpu_state=0;
  //
  reg [2:0] n_instr_stg;
  reg [3:0] n_cpu_state;

  always @(posedge clk) begin
    instr_stg<=n_instr_stg;
    cpu_state<=n_cpu_state;
  end
  
  always @* begin
    n_cpu_state=cpu_state;
    n_instr_stg=instr_stg;
    cede=0;
    case (state)
      0:begin
        n_cpu_state=0;
        n_instr_stg=0;
      end
      1:case (cpu_state)
        0: n_cpu_state=1;
        1: if (memctrl_ready) n_cpu_state=2;
        2:
        case (instr[6:0])
          7'b1100111:case (instr_stg) //jalr
            0:n_instr_stg=1;
            1:n_instr_stg=2;
            2:begin
              n_instr_stg=0;
              n_cpu_state=1;
            end
          endcase
          //
          7'b1100011:case (instr[14:12])
            default:case (instr_stg) //all branch instructions
              0:n_instr_stg=1; //load flags to temp
              1:begin //set new pc accordingly
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
          endcase
          //
          7'b0000011:case (instr[14:12])
            0:case (instr_stg) //lb
              0: n_instr_stg=1; //drive alu_c to memctrl's ad, set cmd, set en
              1: if (memctrl_ready) n_instr_stg=2; //when ready load to rd
              2: begin //sign-extend it
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0: n_instr_stg=1; //drive alu_c to memctrl's ad, set cmd, set en
              1: if (memctrl_ready) begin //when ready load to rd
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0: n_instr_stg=1; //drive alu_c to memctrl's ad, set cmd, set en
              1: if (memctrl_ready) n_instr_stg=2; //when ready load to rd
              2: begin //sign-extend it
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0: n_instr_stg=1; //drive alu_c to memctrl's ad, set cmd, set en
              1: if (memctrl_ready) begin //when ready load to rd
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0: n_instr_stg=1; //drive alu_c to memctrl's ad, set cmd, set en
              1: if (memctrl_ready) begin //when ready load to rd
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0: n_instr_stg=1; //save src to temp
              1: n_instr_stg=2; //drive alu_c to memctrl's ad, set cmd, set en
              2: if (memctrl_ready) begin //wait for ready
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b001:case (instr_stg) //sh
              0: n_instr_stg=1; //save src to temp
              1: n_instr_stg=2; //drive alu_c to memctrl's ad, set cmd, set en
              2: if (memctrl_ready) begin //wait for ready
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0: n_instr_stg=1; //save src to temp
              1: n_instr_stg=2; //drive alu_c to memctrl's ad, set cmd, set en
              2: if (memctrl_ready) begin //wait for ready
                n_instr_stg=0;
                n_cpu_state=1;
              end
            endcase
          endcase
          7'b0:begin
            cede=1;
          end
          default:begin // unspecified instructions are assumed to take 1 cycle
            n_cpu_state=1;
          end
        endcase
      endcase
    endcase
  end    
endmodule
