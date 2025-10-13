module uart (
  input 
    clk,
    rx_ready,
    tx_ready,
  input [7:0]
    rx_data,
  output reg
    tx_en,
  output reg [7:0]
    tx_data,
  //
  input 
    rd,
  output 
    we,
  output reg [7:0] 
    wd,
  output reg [10:0] 
    ad,
);
  parameter UART_BASE=11'b0;
  reg [10:0] ad=UART_BASE;
  reg [3:0] state=0,stg=0;
  always @(posedge clk) begin
    case (state)
      0:
    endcase
  end
endmodule
