module mem_controller (
  input 
    clk,
    opcode5,
  input [2:0] 
    funct3,
  input [1:0]
    mem_op,
  input [MABL-1:0]
    mem_ad,
  input [31:0] 
    mem_wd,
  output reg
    ready,
  output reg [31:0]
    mem_rd,
  // memory specific ports
  input [7:0] 
    rd,
  output reg
    we,
  output reg [7:0]
    wd,
  output reg [MABL-1:0]
    ad
);
  /* 
    the purpose of this module is to abstract the actual memory interface from the cpu
    if it ever gets deployed in a system with a different type of memory, only this 
    module should be changed.
  */
  parameter MABL=19;
  reg [3:0] state=15,stg=0;
  always @(posedge clk) begin
    case (state)
      4'b1111:
      if (mem_op[1]) begin
        state<=4'b0010;
        stg<=0;
      end
      else if (mem_op[0]) begin
        if ({opcode5,funct3}!=4'b1000) //sb can be done in one cycle
          state={opcode5,funct3};
          stg<=0;
      end
      else if (mem_op==0) begin state<=15;stg<=0; end
      4'b0x00: //lb/lbu
      state<=15;
      4'b0x01: //lh/lhu
      case (stg)
        0:stg++;
        1:begin state<=15;stg<=0; end
      endcase
      4'b0010: //lw
      case (stg)
        0:stg++;
        1:stg++;
        2:stg++;
        3:begin state<=15;stg<=0; end
      endcase
      4'b1001://sh
        state<=15;
      4'b1010://sw
      case (stg)
        0:stg++;
        1:stg++;
        2:begin state<=15;stg<=0; end
      endcase
      default: state<=15;
    endcase
  end
  reg [18:0] ad_reg;
  reg [31:0] rd_reg=0;
  reg rd_we,rd_rst;
  always @(posedge clk) if (rd_rst) rd_reg<=0; else if (rd_we) 
    case (wd_sel)
      0:rd_reg[7:0]<=rd;
      1:rd_reg[15:8]<=rd;
      2:rd_reg[23:16]<=rd;
      3:rd_reg[31:24]<=rd;
    endcase
  
  reg ad_sel;
  reg [1:0] wd_sel;
  reg [1:0] signext;
  reg [1:0] rd_sel,rd_we_sel;
  reg [31:0] mem_out;
  reg [1:0] offset;
  always @* begin
    ad=ad_sel?mem_ad+offset:mem_ad;
    wd=wd_sel[1]?
      (wd_sel[0]?mem_wd[31:24]:mem_wd[23:16]):
      (wd_sel[0]?mem_wd[15:8]:mem_wd[7:0]);
    //wd=8'haa;
    mem_out=rd_sel[1]?
      {rd,rd_reg[23:0]}:
      rd_sel[0]?{16'b0,rd,rd_reg[7:0]}:{24'b0,rd};
    if (signext[1]) mem_rd=signext[0]?{{16{mem_out[15]}},mem_out[15:0]}:{{24{mem_out[7]}},mem_out[7:0]};
    else mem_rd=mem_out;
    signext[1]=!funct3[2]&&!funct3[1]&&!mem_op[1];
    signext[0]=funct3[0];
  end

  always @* begin
    rd_we=0;
    rd_rst=0;
    we=0;
    ready=0;
    wd_sel=2'bxx;
    rd_sel=2'bxx;
    ad_sel=1'bx;
    offset=2'bxx;
    case (state)
      4'b1111:
      if (mem_op[1]) begin
        ad_sel=0;
      end
      else if (mem_op[0]) begin
        ad_sel=0;
        we=opcode5;
        wd_sel=0;
        if ({opcode5,funct3}==4'b1000) ready=1;
      end
      4'b0x00: //lb/lbu
      begin
        rd_sel=0;
        ready=1;
      end
      4'b0x01: //lh/lhu
      case (stg)
        0:begin
          ad_sel=1;
          offset=1;
          rd_we=1;
          wd_sel=0;
        end
        1:begin
          rd_sel=1;
          ready=1;
        end
      endcase
      4'b0010: //lw
      case (stg)
        0:begin
          ad_sel=1;
          offset=1;
          rd_we=1;
          wd_sel=0;
        end
        1:begin
          ad_sel=1;
          offset=2;
          rd_we=1;
          wd_sel=1;
        end
        2:begin
          ad_sel=1;
          offset=3;
          rd_we=1;
          wd_sel=2;
        end
        3:begin
          rd_sel=2;
          ready=1;
        end
      endcase
      4'b1001: //sh
      begin
        ad_sel=1;
        offset=1;
        wd_sel=1;
        we=1;
        ready=1;
      end
      4'b1010: //sw
      case (stg)
        0:begin
          ad_sel=1;
          offset=1;
          wd_sel=1;
          we=1;
        end
        1:begin
          ad_sel=1;
          offset=2;
          wd_sel=2;
          we=1;
        end
        2:begin
          ad_sel=1;
          offset=3;
          wd_sel=3;
          we=1;
          ready=1;
        end
      endcase
      default:begin end
  endcase
end

endmodule
