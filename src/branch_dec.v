module branch_dec (
  input [2:0] 
    funct3,
  input [4:0] 
    alu_flags,
  output reg 
    branch
);
  always @* begin
    case (funct3)
      3'b000: branch=alu_flags[0];
      3'b001: branch=!alu_flags[0];
      3'b100: branch=alu_flags[1];
      3'b101: branch=!alu_flags[1];
      3'b110: branch=!alu_flags[2];
      3'b111: branch=alu_flags[2];
      default: branch=1'bx;
    endcase
  end
endmodule 
