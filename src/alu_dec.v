module alu_dec (
  input [1:0] op,
  input [2:0] funct3,
  input 
    op5,
    funct7,
  output reg cin,arith,
  output reg [3:0] sel,
  output reg flagout, flagsel
);
  always @* begin
    flagout=0;
    case (op)
      0:begin {cin,arith,sel}=main_decoder;flagout=iflagout; end
      1:{cin,arith,sel}=6'b010000;
      2:{cin,arith,sel}=6'b010011;
      3:{cin,arith,sel}=6'b010011;
    endcase
    //if (op[1])
    //  {cin,arith,sel}=6'b010011;
    //else if (op[0])
    //  {cin,arith,sel}=6'b010000;
    //else {cin,arith,sel}=main_decoder;
  end
  reg [5:0] main_decoder;
  reg iflagout,iflagsel;
  always @* begin
    iflagout=0;
    flagsel=1'bx;
    case (funct3)
      3'b000:main_decoder={4'b0100,{2{op5&&funct7}}};
      3'b010:begin main_decoder=6'b010011;iflagout=1;flagsel=0; end
      3'b011:begin main_decoder=6'b010011;iflagout=1;flagsel=1; end
      3'b100:main_decoder=6'b001100;
      3'b110:main_decoder=6'b000100;
      3'b111:main_decoder=6'b001000;
      3'b001:main_decoder=6'b010110;
      3'b101:main_decoder={(funct7),5'b10100};
      default:main_decoder=6'bxxxxxx;
    endcase
  end
endmodule
