module imm_dec (
  input [6:0] op7,
  output reg [2:0] format
);
  always @* begin
    case (op7)
      7'b0110111:format=3;
      7'b0010111:format=3;
      7'b1101111:format=3'b1xx;
      7'b1100111:format=0;
      7'b1100011:format=2;
      7'b0000011:format=0;
      7'b0100011:format=1;
      7'b0010011:format=0;
      default:format=3'bxxx;
    endcase
  end
endmodule
