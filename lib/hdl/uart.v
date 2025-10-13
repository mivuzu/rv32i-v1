module uart_r (input clk, input rx, output reg ready, output reg [7:0] data);
  parameter CLK_FREQ=12_000_000;
  localparam baud_rate=115200;
  localparam cpb=$rtoi($floor(CLK_FREQ/baud_rate));
  localparam hcpb=$rtoi($floor(CLK_FREQ/baud_rate/2));
  localparam len=$rtoi($clog2(cpb));
  reg [1:0] state=0;
  reg [len-1:0] cnt=0;
  reg [7:0] data=0;
  reg [2:0] bits=0;
  reg rx_clk;
  
  always @(posedge clk) begin
    if ((state==1 && cnt>=(hcpb)) || (state&2 && cnt>=cpb)) begin
      rx_clk<=1;
      cnt<=0;
    end
    //else if (state==1 || state==2) begin
    //  rx_clk<=0;
    //  cnt<=cnt+1;
    //end
    else if (|state) begin
      rx_clk<=0;
      cnt<=cnt+1;
    end
    else begin
      rx_clk<=0;
      cnt<=0;
    end
  end

  always @(posedge clk) begin
    case (state)
      0:if (!rx) begin
          state<=1;
          ready<=0;
        end
        else begin
          ready<=0;
          data<=0;
        end
      1:if (rx_clk) state<=2;
      2:if (rx_clk) begin
          if (bits!=7) begin
            //data<={data[6:0],rx};
            data[bits]<=rx;
            bits<=bits+1;
          end
          else begin
            data[bits]<=rx;
            state<=3;
          end
        end
      3:if (rx_clk) begin
        if (rx) begin        
          ready<=1;
          state<=0;
          bits<=0;
        end
        else begin
          state<=0;
          bits<=0;
        end
        end
      
    endcase
  end
endmodule

module uart_t (input clk, input en, input [7:0] data, output reg ready, output reg tx);
  parameter CLK_FREQ=12_000_000;
  parameter WAIT_BEFORE_SAMPLING=1'b0;
  localparam baud_rate=115200;
  localparam cpb=$rtoi($floor(CLK_FREQ/baud_rate));
  localparam len=$rtoi($clog2(cpb));
  // assignments to 0 are apparently necessary
  reg tx_clk,at_stop=0,s0_stg=0;
  reg [len-1:0] cnt;
  reg [7:0] tx_reg=0;
  reg [1:0] state=0;
  reg [2:0] i=0;
  
  always @(posedge clk) begin
    if ((state==1||state==2) && cnt!=cpb) begin
      cnt<=cnt+1;
      tx_clk<=0;
    end
    else if (cnt==cpb) begin
      cnt<=0;
      tx_clk<=1;
    end
  end
  
  always @(posedge clk) begin
    case (state)
      0:if (en) begin
        tx<=0;
        ready<=0;
        if (WAIT_BEFORE_SAMPLING) begin
          if (!s0_stg) s0_stg<=1;
          else begin
            tx_reg<=data;
            state<=1;
            s0_stg<=0;
          end
        end
        else begin
          tx_reg<=data;
          state<=1;
        end
      end
      else begin
        tx<=1;
        ready<=0;
      end
      1:if (tx_clk && i!=7) begin
        tx<=tx_reg[0];
        tx_reg<=tx_reg>>1;
        i<=i+1;
      end
      else if (tx_clk) begin
        tx<=tx_reg[0];
        state<=2;
        //
        //i<=0;
        //
      end
      2:if (tx_clk && !at_stop) begin
        at_stop<=1;
        tx<=1;
        i<=0;
      end
      else if (tx_clk) begin
        state<=0;
        at_stop<=0;
        ready<=1;
      end
    endcase
  end
endmodule
