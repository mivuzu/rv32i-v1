`define base cmd[20:2]
`define size cmd[39:21]

module memmgr (
  input clk,
  input rst,
  input rx_ready,
  input [7:0] rx_data,
  input [7:0] rd,
  input [31:0] rd1,
  input tx_ready,
  output reg we,
  output reg tx_en,
  output reg cede,
  output reg [4:0] ra1,
  output reg [7:0] tx_data,
  output reg [18:0] ad,
  output reg [7:0] wd
  //
  //,input [1:0] btn,
  //input [7:0] dip,
  //output reg [7:0] led
);
  reg tx_en=0;
  
  reg [3:0] state=0;
  reg [3:0] cmd_rcv=0;
  reg [3:0] r_stg=0;
  reg [3:0] w_stg=0;
  reg [39:0] cmd;
  //
  always @(posedge clk) begin
    if (!rst)
      case (state)
        0:
        if (cede) cede<=0;
        else if (rx_ready) begin
          case (cmd_rcv)
            0:begin
              if (rx_data[1:0]==3) cede<=1;
              else if (rx_data[1:0]==2) begin
                cmd[7:0]<=rx_data;
                state<=3;
              end
              else begin
                cmd_rcv++;
                cmd[7:0]<=rx_data;
              end
            end
            1:begin
              cmd_rcv++;
              cmd[15:8]<=rx_data;
            end
            2:begin
              cmd_rcv++;
              cmd[23:16]<=rx_data;
            end
            3:begin
              cmd_rcv++;
              cmd[31:24]<=rx_data;
            end
            4:begin
              cmd_rcv<=0;
              cmd[39:32]<=rx_data;
              if (cmd[0]) state<=2;
              else state<=1;
            end
          endcase  
        end
        1:
        if ( `size != 0)
          case (r_stg)
            0:begin
              r_stg++;
              ad<= `base ;
            end
            1:begin
              r_stg++;
            end
            2:begin
              r_stg++;
              tx_data<=rd;
              tx_en<=1;
              ad<=ad+1;
              `size <= `size -1;
            end
            3: if (tx_ready) begin
              tx_data<=rd;
              ad<=ad+1;
              `size <= `size -1;
            end
            else tx_data<=rd;
          endcase
        else begin
          r_stg<=0;
          tx_en<=0;
          ad<=0;
          state<=0;
        end
        2:
        if ( `size !=0)
          case (w_stg)
            0:begin
              w_stg++;
              ad<= `base ;
            end
            1:
            if (we) begin
              we<=0;
              ad<=ad+1;
            end
            else if (rx_ready) begin
              wd<=rx_data;
              we<=1;
              `size --;
            end
          endcase
        else begin
          w_stg<=0;
          we<=0;
          ad<=0;
          state<=0;
        end
        3:begin
          case (r_stg)
          0:begin
            r_stg++;
            ra1<={cmd[3],cmd[7:4]};
          end
          1:begin
            r_stg++;
            tx_data<=rd1[7:0];
            tx_en<=1;
          end
          2: r_stg++;
          3: if (tx_ready) begin
            tx_data<=rd1[15:8];
            r_stg++;
          end
          4: if (tx_ready) begin
            tx_data<=rd1[23:16];
            r_stg++;
          end
          5: if (tx_ready) begin
            tx_data<=rd1[31:24];
            r_stg++;
          end
          6: r_stg++;
          7:begin
            r_stg<=0;
            tx_en<=0;
            state<=0;
          end
          endcase
        end
      endcase
    else begin
      cmd_rcv<=0;
      cmd<=0;
      cede<=0;
    end
  end 
  //always @* led=~(
  //  wdp[2]?cmd[39:32]:
  //    wdp[1]?
  //      (wdp[0]?cmd[31:24]:cmd[23:16]):
  //      (wdp[0]?cmd[15:8]:cmd[7:0])
  //);
  
  /*
  reg [4:0] ra1=0;
  reg [1:0] state=0,cmd_recv=0;
  reg [2:0] r_stg=0,rrf=0;
  reg w_recv=0;
  //reg we;
  reg r_sent=0;
  reg [10:0] len=0;
  //reg [15:0] wd;
  //always @* wd[17:8]=0;
  reg [10:0] addr=0;
  always @* ad={addr,3'b000};

  //
  reg [23:0] cmd;
  always @(posedge clk)
  if (!rst)
    case (state)
      0:begin
        if (rx_ready) begin
          if (cmd_recv==0) begin
            if (rx_data[1:0]==2) cede<=1;
            else if (rx_data[1:0]==3) begin
              cmd[7:0]<=rx_data;
              state<=3;
            end
            else begin
              cmd[7:0]<=rx_data;
              cmd_recv<=cmd_recv+1;
            end
          end
          else if (cmd_recv==1) begin
            cmd[15:8]<=rx_data;
            cmd_recv<=cmd_recv+1;
          end
          else if (cmd_recv==2) begin
            cmd[23:16]<=rx_data;
            cmd_recv<=0;
            addr<=cmd[12:2];
            len<={rx_data,cmd[15:13]};
            state<=cmd[0]?1:2;
          end
        end
        else if (cede) cede<=0;
      end
      1:begin
        if (len!=0) begin
          if (rx_ready) begin
            wd[7:0]<=rx_data;
            we<=1;
          end
          if (we) begin
            we<=0;
            addr<=addr+1;
            len<=len-1;
          end
        end
        else begin
          addr<=0;
          state<=0;
        end
      end
      2:
        if (len!=0) begin
          if (r_stg==0)
            r_stg<=1;
          else if (r_stg==1) begin
            tx_data<=rd[7:0];
            tx_en<=1;
            r_stg<=2;
          end
          else if (r_stg==2) begin
            addr<=addr+1;
            len<=len-1;
            r_stg<=3;
          end
          else if (tx_ready) begin
            tx_data<=rd[7:0];
            addr<=addr+1;
            len<=len-1;
          end
        end
        else begin
          r_stg<=0;
          tx_en<=0;
          r_sent<=0;
          state<=0;
        end
      3:
        if (rrf==0) begin
          ra1<={cmd[3],cmd[7:4]};
          rrf<=1;
        end
        else if (rrf==1) begin
          tx_data<=rd1[7:0];
          tx_en<=1;
          rrf<=2;
        end
        //
        else if (tx_ready && rrf==2) begin
          tx_data<=rd1[15:8];
          rrf<=3;
        end
        else if (tx_ready && rrf==3) begin
          tx_data<=rd1[23:16];
          rrf<=4;
        end
        else if (tx_ready && rrf==4) begin
          tx_data<=rd1[31:24];
          rrf<=5;
        end
        else if (rrf==5) begin
          rrf<=0;
          tx_en<=0;
          state<=0;
        end
        //
        //else if (rrf==2) begin
        //  rrf<=3;
        //end
        //else if (rrf==3) begin
        //  rrf<=0;
        //  tx_en<=0;
        //  state<=0;
        //end
    endcase
  else begin
    cmd_recv<=0;
    cmd<=0;
  end
  */
endmodule

/*
module memmgr_18 (
  input clk,
  input rx_ready,
  input [7:0] rx_data,
  input [17:0] rd,
  input tx_ready,
  output reg we,
  output reg tx_en,
  output reg [7:0] tx_data,
  output reg [13:0] ad,
  output reg [17:0] wd
);
  reg [1:0] state=0,cmd_recv=0;
  reg [2:0] r_stg=0;
  reg w_recv=0;
  //reg we;
  reg r_sent=0;
  reg [9:0] len=0;
  //reg [15:0] wd;
  always @* wd[17:16]=0;
  reg [9:0] addr=0;
  always @* ad={addr,4'b0011};

  //
  reg [23:0] cmd;
  always @(posedge clk)
    case (state)
      0:begin
        //if (!btn[0] && !_btn) begin
        //  addr<=addr+1;
        //  _btn<=1;
        //end
        //else if (btn[0])
        //  _btn<=0;
        //if (!btn[1]) addr<=0;
        
        if (rx_ready) begin
          if (cmd_recv==0) begin
            cmd[7:0]<=rx_data;
            cmd_recv<=cmd_recv+1;
          end
          else if (cmd_recv==1) begin
            cmd[15:8]<=rx_data;
            cmd_recv<=cmd_recv+1;
          end
          else if (cmd_recv==2) begin
            cmd[23:16]<=rx_data;
            cmd_recv<=0;
            addr<=cmd[10:1];
            len<=cmd[20:11];
            state<=cmd[0]?1:2;
          end
        end
      end
      1:begin
        if (len!=0) begin
          if (rx_ready)
            if (!w_recv) begin
              wd[7:0]<=rx_data;
              w_recv<=1;
            end
            else begin
              wd[15:8]<=rx_data;
              w_recv<=0;
              we<=1;
            end
          if (we) begin
            we<=0;
            addr<=addr+1;
            len<=len-1;
          end
        end
        else begin
          state<=0;
        end
      end
      2:
        if (len!=0) begin
          if (r_stg==0) begin
            r_stg<=1;
          end
          else if (r_stg==1) begin
            tx_data<=rd[7:0];
            tx_en<=1;
            r_stg<=2;
          end
          else if (tx_ready && !r_sent) begin
            tx_data<=rd[15:8];
            addr<=addr+1;
            len<=len-1;
            r_sent<=1;
          end
          else if (tx_ready) begin
            tx_data<=rd[7:0];
            r_sent<=0;
          end
        end
        else begin
          r_stg<=0;
          tx_en<=0;
          r_sent<=0;
          state<=0;
        end
    endcase
  
endmodule

*/
