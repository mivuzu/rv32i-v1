module mem_controller (
  input 
    clk,
    en,
  input [2:0] 
    cmd,
  input [MABL-1:0]
    base,
  input [31:0] 
    data,
  output reg
    ready,
  output reg [31:0]
    rmem,
  // memory specific ports
  input [7:0] 
    rd,
  output reg
    we,
  output reg [7:0]
    wd,
  output reg [MABL-1:0]
    ad
  //
  //,output [3:0] state,stg
);
  /* 
    the purpose of this module is to abstract the actual memory interface from the cpu
    if it ever gets deployed in a system with a different type of memory, only this 
    module should be changed.
  */
  parameter MABL=19;
  reg [3:0] state=0,stg=0;
  reg [2:0] cmd_reg;
  reg [31:0] data_reg;
  always @(posedge clk) begin
    case (state)
      0:if (en) begin
        cmd_reg<=cmd;
        //ad<=base;
        data_reg<=data;
        state<=1;
      end
      1:
      case (cmd_reg)
        3'b000: //fetch byte
        case (stg)
          0: stg++; // reset rmem, assume ad is base, wait for sample
          1: stg++; // wait for output
          2: begin  // save to rmem and set ready
            stg<=0;
            state<=0;
          end
        endcase
        3'b001: //fetch half word
        case (stg)
          0: stg++; // ...
          1: stg++; // increment ad as waiting for first output
          2: stg++; // save to rmem[7:0]
          3: begin  // save to rmem[15:8] and set ready
            stg<=0;
            state<=0;
          end
        endcase
        3'b010: //fetch word
        case (stg)
          0: stg++; // ...
          1: stg++; // ...
          2: stg++; // increment ad and save to rmem[7:0]
          3: stg++; // increment ad and save to rmem[15:8]
          4: stg++; // save to rmem[23:16]
          5: begin  // save to rmem[31:24] and set ready
            stg<=0;
            state<=0;
          end
        endcase
        3'b100: //write byte
        case (stg)
          0: begin  // drive data[7:0] to rd, assume ad is base, set we, set ready
            stg<=0;
            state<=0;
          end
        endcase
        3'b101: //write half word
        case (stg)
          0: stg++; // drive data[7:0] to rd, assume ad is base, increment ad, set we
          1: begin  // drive data[15:8] to rd, set we, set ready
            stg<=0;
            state<=0;
          end
        endcase
        3'b110: //write word
        case (stg)
          0: stg++; // drive data[7:0] to rd, assume ad is base, increment ad, set we
          1: stg++; // same but with data[15:8]
          2: stg++; // same but with data[23:16]
          3: begin  // drive data[31:24] to rd, set we, set ready
            stg<=0;
            state<=0;
          end
        endcase
      endcase
    endcase
  end

  reg ad_we,ad_sel;
  reg rmem_we,rmem_rst,nready;
  reg [1:0] rmem_sel,wd_sel;
  always @(posedge clk) begin
    if (rmem_rst) rmem<=0;
    else if (rmem_we)
      case (rmem_sel)
        0: rmem[7:0]<=rd;
        1: rmem[15:8]<=rd;
        2: rmem[23:16]<=rd;
        3: rmem[31:24]<=rd;
      endcase
    if (ad_we)
      ad<=ad_sel?ad+1:base;
    ready<=nready;
  end
  always @* begin
    case (wd_sel)
      0: wd=data_reg[7:0];
      1: wd=data_reg[15:8];
      2: wd=data_reg[23:16];
      3: wd=data_reg[31:24];
    endcase
  end

  always @* begin
    we=0;
    ad_we=0;
    ad_sel=0;
    rmem_we=0;
    rmem_rst=0;
    rmem_sel=2'b0;
    wd_sel=2'b0;
    nready=0;
    case (state)
      0:
      if (en) begin
        ad_we=1;
      end
      1:
      case (cmd_reg)
        3'b000: //fetch byte
        case (stg)
          0:rmem_rst=1;
          1:begin end
          2:begin
            rmem_we=1;
            //rmem_sel=0;
            nready=1;
          end
        endcase
        3'b001: //fetch half word
        case (stg)
          0:rmem_rst=1;
          1:begin
            ad_we=1;
            ad_sel=1;
          end
          2:begin
            rmem_we=1;
            //rmem_sel=0;
          end
          3:begin
            rmem_we=1;
            rmem_sel=1;
            nready=1;
          end
        endcase
        3'b010: //fetch word
        case (stg)
          0:rmem_rst=1;
          1:begin
            ad_we=1;
            ad_sel=1;
          end
          2:begin
            ad_we=1;
            ad_sel=1;
            rmem_we=1;
          end
          3:begin
            ad_we=1;
            ad_sel=1;
            rmem_we=1;
            rmem_sel=1;
          end
          4:begin
            rmem_we=1;
            rmem_sel=2;
          end
          5:begin
            rmem_we=1;
            rmem_sel=3;
            nready=1;
          end
        endcase
        3'b100: //write byte
        case (stg)
          0:begin
            wd_sel=0;
            we=1;
            nready=1;
          end
        endcase
        3'b101: //write half word
        case (stg)
          0:begin
            ad_we=1;
            ad_sel=1;
            wd_sel=0;
            we=1;
          end
          1:begin
            wd_sel=1;
            we=1;
            nready=1;
          end
        endcase
        3'b110: //write word
        case (stg)
          0:begin
            ad_we=1;
            ad_sel=1;
            wd_sel=0;
            we=1;
          end
          1:begin
            ad_we=1;
            ad_sel=1;
            wd_sel=1;
            we=1;
          end
          2:begin
            ad_we=1;
            ad_sel=1;
            wd_sel=2;
            we=1;
          end
          3:begin
            wd_sel=3;
            we=1;
            nready=1;
          end
        endcase
      endcase
    endcase
  end

endmodule
