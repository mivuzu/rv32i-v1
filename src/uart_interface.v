module uart (
  input 
    clk,
    rx_ready,
    tx_ready,
  input [7:0]
    rx_data,
  output reg
    tx_en,
    wait,
  output reg [7:0]
    tx_data,
  //
  input [7:0] 
    rx_rd,
    tx_rd,
  output reg
    rx_we,
    tx_we,
  output reg [7:0] 
    rx_wd,
    tx_wd,
  output reg [MABL-1:0] 
    rx_ad,
    tx_ad
);

  parameter UART_BASE=11'b0;
  parameter MABL=11;
  reg [3:0] rx_state=0,tx_state=0;
  always @(posedge clk) begin
    case (rx_state)
      0: if (rx_ready) rx_state++;
      1: rx_state++;
      2: rx_state++;
      3: rx_state++;
      4: rx_state++;
      5: rx_state<=0;
    endcase
    case (tx_state)
      0: if (tx_rd[0]) tx_state++;
      1: tx_state++;
      2: tx_state++;
      3: tx_state++;
      4: if (tx_cnt!=0 && tx_cnt<2046) tx_state++; else tx_state<=7;
      5: if (tx_cnt!=0) tx_state++; else tx_state<=7;
      6: if (tx_ready) tx_state<=4;
      7: tx_state<=0;
    endcase
  end
  always @* wait=(rx_state!=0||tx_state!=0);

  reg tx_en;
  reg [7:0] tx_data;
  reg rx_we,tx_we,rx_data_we;
  reg [7:0] rx_wd,tx_wd,reg_rx_data=0;
  reg rx_ad_we,tx_ad_we;
  reg [MABL-1:0] rx_ad,tx_ad,reg_tx_ad=UART_BASE;
  reg prx_cnt_we,rx_cnt_we;
  reg [7:0] prx_cnt=0;
  wire [MABL-1:0] actual_prx_cnt={rx_rd[2:0],prx_cnt[7:0]};
  reg [MABL-1:0] rx_cnt=0,nrx_cnt;
  reg tx_cnt_we;
  reg [MABL-1:0] tx_cnt=0,ntx_cnt;
  always @(posedge clk) begin
    if (tx_ad_we) reg_tx_ad<=tx_ad;    
    if (prx_cnt_we) prx_cnt<=rx_rd;
    if (rx_cnt_we) rx_cnt<=nrx_cnt;
    if (tx_cnt_we) tx_cnt<=ntx_cnt;
    if (rx_data_we) reg_rx_data<=rx_data;
  end
  reg [1:0] rx_ad_sel;
  reg [1:0] tx_ad_sel;
  reg [1:0] tx_cnt_sel;
  reg [1:0] rx_wd_sel;
  reg tx_wd_sel;
  always @* begin
    //rx_ad
    case (rx_ad_sel)
      0: rx_ad=UART_BASE;
      1: rx_ad=UART_BASE+1;
      2: rx_ad=UART_BASE+2;
      3: rx_ad=rx_cnt+2;
    endcase
    // tx_ad
    case (tx_ad_sel)
      0: tx_ad=UART_BASE;
      1: tx_ad=reg_tx_ad+1;
    endcase
    // nrx_cnt
    nrx_cnt=(actual_prx_cnt<2045)?actual_prx_cnt+1:1;
    // ntx_cnt
    case (tx_cnt_sel)
      0: ntx_cnt={3'b0,tx_rd[7:0]};
      1: ntx_cnt={tx_rd[2:0],tx_cnt[7:0]};
      2: ntx_cnt=tx_cnt-1;
      3: ntx_cnt=0;
    endcase
    // rx_wd
    case (rx_wd_sel)
      0: rx_wd=1;
      1: rx_wd={5'b0,nrx_cnt[10:8]};
      2: rx_wd=rx_cnt[7:0];
      3: rx_wd=reg_rx_data;
    endcase
    // tx_wd
    tx_wd=tx_wd_sel?8'h00:8'h8e;
    //tx_wd=8'h80;
    // tx_data
    tx_data=tx_rd;
  end

  always @* begin
    rx_we=0;
    rx_ad_sel=0;
    rx_wd_sel=0;
    prx_cnt_we=0;
    rx_cnt_we=0;
    rx_data_we=0;
    
    case (rx_state)
      0:if (rx_ready) begin
        rx_ad_sel=1;
        rx_data_we=1;
      end
      1:begin
        prx_cnt_we=1;
        rx_ad_sel=2;
      end
      2:begin
        rx_we=1;
        rx_wd_sel=1;
        rx_ad_sel=2;
        rx_cnt_we=1;
      end
      3:begin 
        rx_we=1;
        rx_wd_sel=2;
        rx_ad_sel=1;
      end
      4:begin
        rx_we=1;
        rx_wd_sel=3;
        rx_ad_sel=3;
      end
      5:begin
        rx_we=1;
        rx_wd_sel=0;
        rx_ad_sel=0;
      end
    endcase

    tx_en=0;
    tx_we=0;
    tx_ad_sel=0;
    tx_ad_we=0;
    tx_cnt_we=0;
    tx_cnt_sel=0;
    tx_wd_sel=0;
    
    case (tx_state)
      0:if (tx_rd[0]) begin
        tx_we=1;
        tx_wd_sel=0;
      end
      1:begin
        tx_ad_sel=1;
        tx_ad_we=1;
      end
      2:begin
        tx_ad_sel=1;
        tx_ad_we=1;
        tx_cnt_we=1;
      end
      3:begin
        tx_ad_sel=1;
        tx_cnt_we=1;
        tx_cnt_sel=1;
        //tx_en=1;
      end
      4:begin
        tx_ad_sel=1;
        if (tx_cnt!=0 && tx_cnt<2046) begin
          tx_en=1;
          tx_cnt_we=1;
          tx_cnt_sel=2;
        end
      end
      5:begin
        tx_ad_sel=1;
        if (tx_cnt!=0) begin
          tx_ad_we=1;
        end
      end
      6:begin
        tx_ad_sel=1;
        if (tx_ready) tx_en=1;
      end
      7:begin
        tx_ad_sel=0;
        tx_ad_we=1;
        tx_we=1;
        tx_wd_sel=1;
        tx_cnt_we=1;
        tx_cnt_sel=3;
      end
    endcase
  end
endmodule
