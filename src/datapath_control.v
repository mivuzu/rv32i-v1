module datapath_control (
	input 
    state,
    memctrl_ready,
  input [2:0] 
    instr_stg,
  input [3:0]
    cpu_state,
  input [4:0]
    memmgr_ra1,
  input [31:0] 
    instr,
    temp,
  output reg  
    instr_we,
    rf_we,
    rf_pc_we, 
    temp_we,
    temp_sel,
    alu_arith,
    alu_cin,
    memctrl_en,
  output reg [1:0]
    pc_sel,
    a_sel,
    b_sel,
  output reg [2:0]
    wd_sel,
    format,
    memctrl_cmd,
  output reg [3:0]
    alu_sel,
  output reg [4:0]
    rf_ra1,
    rf_ra2,
    rf_wa
);
    always @* begin
      rf_we     = 1'b0;
      rf_pc_we  = 1'b0;
      wd_sel    = 3'b000;
      pc_sel    = 2'b00;
      a_sel     = 2'b0;
      b_sel     = 2'b0;
      alu_arith = 1'b0;
      alu_sel   = 4'b0000;
      alu_cin   = 1'b0;
      format    = 3'd0;
      temp_sel  = 1'b0;
      temp_we   = 1'b0;
      rf_ra1    = instr[19:15];
      rf_ra2    = instr[24:20];
      rf_wa     = instr[11:7];
      instr_we=0;
      memctrl_cmd=3'b010; //read word
      memctrl_en=0; 
      
      case (cpu_state)
        0: if (state) begin
          pc_sel=1; // init_addr
          //
          rf_pc_we=1;
          memctrl_en=1;
        end
        else rf_ra1=memmgr_ra1;
        1: if (memctrl_ready) begin
          instr_we=1;
        end
        2:case (instr[6:0])
          7'b0110111: begin //lui
            format=3;
            b_sel=1;
            alu_sel=4'b0011;
            rf_we=1;
            //
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'b0010111:begin //auipc
            format=3;
            a_sel=1;
            b_sel=1;
            alu_arith=1;
            rf_we=1;
            //
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'b1101111:begin // jal
            format=4;
            a_sel=1;
            b_sel=1;
            alu_arith=1;
            alu_sel=0;     // alu=pc+imm
            wd_sel=2'b10; // wd=alu+4
            pc_sel=2'b11; // pc=alu
            rf_we=1;
            //
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'b1100111: case (instr_stg) //jalr
            0:begin // temp<={{31{1'b1}},1'b0} mayhaps it's a little wasteful to compute a constant within an instruction
              a_sel=0;
              rf_ra1=5'd0;
              alu_arith=1;
              alu_sel=4'b1111;
              temp_we=1;
            end
            1:begin // rd<=rs1+imm;
              format=0;
              a_sel=0;
              b_sel=1;
              alu_arith=1;
              alu_sel=0;
              rf_we=1;
            end
            2:begin //rd<=(rd&temp)+4;pc<=(rd&temp);
              a_sel=0;
              rf_ra1=instr[11:7];
              b_sel=2'b10;
              alu_arith=0;
              alu_sel=4'b1000;
              pc_sel=2'b11; // pc_in=alu;
              wd_sel=2'b10; // wd=pc_next (alu+4)
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
          endcase
          //
          7'b1100011: case (instr[14:12])
            0:case (instr_stg) //beq
              0:begin
                alu_arith=1;
                alu_sel=4'b0011; //rs1-rs2
                temp_sel=1; //flags
                temp_we=1;
              end            
              1:if (temp[0]) begin // if zero
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
            3'b1:case (instr_stg) //bne
              0:begin
                alu_arith=1;
                alu_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[0]) begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
            3'b100:case (instr_stg) //blt
              0:begin
                alu_arith=1;
                alu_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[1]) begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
            3'b110:case (instr_stg) //bltu
              0:begin
                alu_arith=1;
                alu_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[2]) begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
            3'b101:case (instr_stg) //bge
              0:begin
                alu_arith=1;
                alu_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[1]) begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
            3'b111:case (instr_stg) //bgeu
              0:begin
                alu_arith=1;
                alu_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[2]) begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  alu_arith=1;
                  alu_sel=0;
                  pc_sel=2'b11;
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
                else begin
                  pc_sel=0;                  
                  //
                  rf_pc_we=1;
                  memctrl_en=1;
                end
            endcase
          endcase
          //
          7'b0000011: case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin
                format=0; //I
                b_sel=1;
                alu_arith=1;
                alu_sel=0; // rs1+imm
                //
                pc_sel=2'b11; //pass alu to memctrl_ad
                memctrl_cmd=3'b0; //read byte
                memctrl_en=1;
              end
              1: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
              end
              2:begin
                rf_ra1=instr[11:7];
                alu_arith=1;
                alu_sel=4'b1000;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin
                format=0; //I
                b_sel=1;
                alu_arith=1;
                alu_sel=0; // rs1+imm
                //
                pc_sel=2'b11; //pass alu to memctrl_ad
                memctrl_cmd=3'b0; //read byte
                memctrl_en=1;
              end
              1: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin
                format=0; //I
                b_sel=1;
                alu_arith=1;
                alu_sel=0; // rs1+imm
                //
                pc_sel=2'b11; //pass alu to memctrl_ad
                memctrl_cmd=3'b1; //read half word
                memctrl_en=1;
              end
              1: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
              end
              2:begin
                rf_ra1=instr[11:7];
                alu_arith=1;
                alu_sel=4'b1001;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin
                format=0; //I
                b_sel=1;
                alu_arith=1;
                alu_sel=0; // rs1+imm
                //
                pc_sel=2'b11; //pass alu to memctrl_ad
                memctrl_cmd=3'b1; //read half word
                memctrl_en=1;
              end
              1: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin
                format=0; //I
                b_sel=1;
                alu_arith=1;
                alu_sel=0; // rs1+imm
                //
                pc_sel=2'b11; //pass alu to memctrl_ad
                memctrl_en=1;
              end
              1: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0:begin
                alu_arith=0;
                alu_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                alu_arith=1;
                alu_sel=0;
                //
                pc_sel=2'b11; // pass alu to memctrl_ad
                memctrl_cmd=3'b100; //write byte
                memctrl_en=1;
              end
              2: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b1:case (instr_stg) //sh
              0:begin
                alu_arith=0;
                alu_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                alu_arith=1;
                alu_sel=0;
                //
                pc_sel=2'b11; // pass alu to memctrl_ad
                memctrl_cmd=3'b101; //write half word
                memctrl_en=1;
              end
              2: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0:begin
                alu_arith=0;
                alu_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                alu_arith=1;
                alu_sel=0;
                //
                pc_sel=2'b11; // pass alu to memctrl_ad
                memctrl_cmd=3'b110; //write word
                memctrl_en=1;
              end
              2: if (memctrl_ready) begin
                wd_sel=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
          endcase
          7'b0010011: case (instr[14:12])
            3'b0:begin //addi
              format=0;
              a_sel=0;
              b_sel=1;
              alu_arith=1;
              alu_sel=0;
              wd_sel=0;
              rf_we=1;
              pc_sel=0;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b010:begin //slti
              format=0;
              b_sel=1;
              alu_arith=1;
              alu_sel=4'b0011;
              wd_sel=3'b100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b011:begin //sltiu
              format=0;
              b_sel=1;
              alu_arith=1;
              alu_sel=4'b0011;
              wd_sel=3'b101;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b100:begin //xori
              format=0;
              b_sel=1;
              alu_sel=4'b1100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b110:begin //ori
              format=0;
              b_sel=1;
              alu_sel=4'b0100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b111:begin //andi
              format=0;
              b_sel=1;
              alu_sel=4'b1000;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b001:begin //slli
              b_sel=1;
              alu_arith=1;
              alu_sel=4'b0110;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b101:case (instr[30])
              0:begin //srli
                b_sel=1;
                alu_arith=1;
                alu_sel=4'b0100;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
              1:begin //srai
                b_sel=1;
                alu_arith=1;
                alu_cin=1;
                alu_sel=4'b0100;
                rf_we=1;
                //
                rf_pc_we=1;                
                memctrl_en=1;
              end
            endcase
          endcase
          7'b0110011: case (instr[14:12])
            3'b0: case (instr[30])
              0:begin //add
                alu_arith=1;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
              1:begin //sub
                alu_arith=1;
                alu_sel=4'b0011;
                rf_we=1;
                //
                rf_pc_we=1;
                memctrl_en=1;
              end
            endcase
            3'b1:begin //sll
              alu_arith=1;
              alu_sel=4'b0110;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b010:begin //slt
              alu_arith=1;
              alu_sel=4'b0011;
              wd_sel=3'b100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b011:begin //sltu
              alu_arith=1;
              alu_sel=4'b0011;
              wd_sel=3'b101;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b100:begin //xor
              alu_sel=4'b1100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b101:if (!instr[30]) begin //srl
              alu_arith=1;
              alu_sel=4'b0100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            else begin //sra
              alu_arith=1;
              alu_cin=1;
              alu_sel=4'b0100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b110:begin //or
              alu_sel=4'b0100;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
            3'b111:begin //and
              alu_sel=4'b1000;
              rf_we=1;
              //
              rf_pc_we=1;
              memctrl_en=1;
            end
          endcase
          //7'd1:begin //made up instruction to load imm I to x1
          //  format=2;
          //  rf_wa=5'd1;
          //  b_sel=1; //imm
          //  alu_arith=0;
          //  alu_sel=4'b0011; //passthrough b
          //
          //  rf_pc_we=1;
          //memctrl_en=1;
          //  rf_we=1;
          //end
          7'd1:begin //made up instruction to load flags of rs1-rs2 to temp
            alu_arith=1;
            alu_sel=4'b0011; //subtract
            temp_sel=1;
            temp_we=1;
            //
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'd2:begin //made up instruction to load temp to x1
            rf_wa=5'd1;
            wd_sel=3'b011; 
            rf_we=1;
          
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'd127:begin // made up instruction to load rmem to x1
            rf_wa=5'd1;
            wd_sel=1; 
            rf_we=1;
          
            rf_pc_we=1;
            memctrl_en=1;
          end
          7'd0:begin
            //rf_ra1=5'b1;
          end
          default:begin
            rf_pc_we=1;
            memctrl_en=1;
          end
        endcase
      endcase
      //*/
    end
endmodule
