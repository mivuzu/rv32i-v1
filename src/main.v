module main (input i_clk, input rx, input [1:0] btn, input [7:0] dip, output tx, output reg [7:0] led);
  wire clk;
  pll u_pll (.iclk12(i_clk),.clk100(clk));
  localparam clk_freq=100_000_000;

  reg state=0;
  reg [1:0] pbtn=0;
  always @(posedge clk) begin
    pbtn[0]<=btn[0];
    pbtn[1]<=pbtn[0];
    if ( (pbtn[1] && !pbtn[0]) || u2_cede || cpu_cede) begin
      pbtn<=0;
      state<=~state;
    end
  end
  
  wire [7:0] u0_data;
  wire u0_ready;
  uart_r #(.CLKFREQ(clk_freq)) u0 (clk,rx,u0_ready,u0_data);

  reg u1_en;
  reg [7:0] u1_data;
  wire u1_ready;
  uart_t #(.CLKFREQ(clk_freq)) u1 (clk,u1_en,u1_data,u1_ready,tx);
  
  always @* begin
    case (state)
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
  wire [3:0] cpu_state;

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
    //// led
    instr,
    cpu_state
  );
  wire [1:0] pc_sel;
  wire pc_we,branch;

  wire uart_tx_en,uart_rx_we,uart_tx_we,uart_wait;
  wire [7:0] uart_tx_data,uart_rx_wd,uart_tx_wd;
  wire [smabl-1:0] uart_rx_ad,uart_tx_ad;
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
  );

  always @* led=~(
    ~btn[1]?{cpu_state,3'b0,state}:
    (dip[1]?
      (dip[0]?instr[31:24]:instr[23:16]):
      (dip[0]?instr[15:8]:instr[7:0])
    )
  );
  //always @* led=~(
  //~btn[1]?
  //  (dip[1]?
  //  uart_rx_state:
  //  dip[0]?{8'b0}:{pc_sel,u3_wea,branch,cpu_state}
  //  )
  //  :
  //  (dip[7]?
  //  dip[6]?
  //    (dip[1]?(dip[0]?prev_pc[31:24]:prev_pc[23:16]):(dip[0]?prev_pc[15:8]:prev_pc[7:0])):
  //    (dip[1]?(dip[0]?pc[31:24]:pc[23:16]):(dip[0]?pc[15:8]:pc[7:0])):
  //  (dip[1]?(dip[0]?instr[31:24]:instr[23:16]):(dip[0]?instr[15:8]:instr[7:0]))
  //  )
  //);

endmodule
