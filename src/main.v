module main (input i_clk, input rx, input [1:0] btn, input [7:0] dip, output tx, output reg [7:0] led);
  localparam clk_freq=50_000_000;
  wire clk;
  clk12_to_50 u_clk (i_clk,clk);
  //localparam clk_freq=12_000_000;
  //wire clk=i_clk;

  reg state=0, _btn0=0, __btn0=0;
  always @(posedge clk) begin
    _btn0<=btn[0];
    __btn0<=_btn0;
    if ( (__btn0 && !_btn0) || u2_cede || cpu_cede) begin
      _btn0<=0;
      __btn0<=0;
      state<=~state;
    end
  end
  wire [7:0] u0_data;
  wire u0_ready;
  uart_r #(.CLK_FREQ(clk_freq)) u0 (clk,rx,u0_ready,u0_data);

  reg u1_en;
  reg [7:0] u1_data;
  wire u1_ready;
  uart_t #(.CLK_FREQ(clk_freq), .WAIT_BEFORE_SAMPLING(1)) u1 (clk,u1_en,u1_data,u1_ready,tx);
  
  always @* begin
    case (state /*|| uart_wait*/)
      0:begin
        u1_en=u2_tx_en;
        u1_data=u2_tx_data;
        u3_wea=u2_we;
        u3_wda=u2_di;
        u3_ada=u2_ad;
        u3_web=0;
        u3_wec=0;
      end
      1:begin
        u1_en=uart_tx_en;
        u1_data=uart_tx_data;
        u3_wea=cpu_we;
        u3_wda=cpu_wd;
        u3_ada=cpu_ad;
        u3_web=uart_tx_we;
        u3_wec=uart_rx_we;
      end
    endcase
  end
  

  localparam mabl=19;
  localparam smabl=11;
  reg u2_we,u2_tx_en,u2_cede;
  wire [4:0] u2_ra1;
  wire [7:0] u2_tx_data;
  wire [mabl-1:0] u2_ad;
  wire [7:0] u2_di;

  memmgr u2 (
    clk,
    state,
    u0_ready,
    u0_data,
    u3_rda,
    rf_rd1,
    u1_ready,
    u2_we,
    u2_tx_en,
    u2_cede,
    u2_ra1,
    u2_tx_data,
    u2_ad,
    u2_di
  );
  
  reg u3_wea,u3_web,u3_wec;
  reg [7:0] u3_wda;
  reg [mabl-1:0] u3_ada;
  wire [7:0] u3_rda,u3_rdb,u3_rdc;
  
  memory u3 (
    .clk(clk),
    .we_a(u3_wea),
    .we_b(u3_web),
    .we_c(u3_wec),
    .wd_a(u3_wda[7:0]),
    .wd_b(uart_tx_wd),
    .wd_c(uart_rx_wd),
    .addr_a(u3_ada),
    .addr_b(uart_tx_ad),
    .addr_c(uart_rx_ad),
    .rd_a(u3_rda[7:0]),
    .rd_b(u3_rdb),
    .rd_c(u3_rdc)
  );

  wire cpu_cede,cpu_we;
  wire [7:0] cpu_wd;
  wire [mabl-1:0] cpu_ad;
  wire [31:0] rf_rd1,instr;
  core u4 (
    clk,
    state,
    //
    cpu_cede,
    //// memory specific
    u3_rda,
    //
    cpu_we,
    cpu_wd,
    cpu_ad,
    //// memmgr
    u2_ra1,
    rf_rd1,
    //// led </3
    instr
  );

  wire uart_tx_en,uart_rx_we,uart_tx_we,uart_wait;
  wire [7:0] uart_tx_data,uart_rx_wd,uart_tx_wd;
  wire [smabl-1:0] uart_rx_ad,uart_tx_ad;
  //
  wire [3:0] uart_rx_state,uart_tx_state;
  uart u5 (
    clk,
    state&u0_ready,
    u1_ready,
    u0_data,
    uart_tx_en,
    uart_wait,
    uart_tx_data,
    u3_rdc,
    u3_rdb,
    uart_rx_we,
    uart_tx_we,
    uart_rx_wd,
    uart_tx_wd,
    uart_rx_ad,
    uart_tx_ad
    //
    ,uart_rx_state,uart_tx_state
  );
  
  always @* led=~(
  ~btn[1]?
    (dip[1]?
      uart_rx_state:
      dip[0]?{4'b0,uart_tx_state}:{7'b0,state}):
    (dip[1]?
      (dip[0]?instr[31:24]:instr[23:16]):
      (dip[0]?instr[15:8]:instr[7:0]))
  );

endmodule
