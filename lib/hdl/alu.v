module alu #(parameter n=32) (
  input 
   cin,
   arith,
  input [3:0] 
    sel,
  input [n-1:0] 
    a,
    b,
  output reg [4:0] 
    flags,
  output reg [n-1:0] 
    c
);
  integer i;
  reg [n-1:0] a_to,b_to;
  reg a_swap,b_swap;
  always @* begin
      a_swap=sel[1]&~sel[0];
      b_swap=~sel[1]&sel[0];
      a_to=a^{n{a_swap}};
      b_to=b^{n{b_swap}};
  end

  wire [n-1:0] u0_out;
  shift_rotate u0 (sel[1],cin,sel[0],b[4:0],a,u0_out);
  
  reg [n-1:0] u1_a,u1_b;
  reg u1_subtr,u1_cin;
  wire [n:0] u1_out;
  wire u1_overflow;
  adder u1 (u1_subtr,u1_cin,u1_a,u1_b,u1_out,u1_overflow);
  always @* begin
    u1_subtr=&sel[3:2]&sel[0]|&sel[1:0];
    u1_cin=cin&~sel[3];
    u1_a=&sel?~a_to:a_to;
    u1_b[n-1:1]=b_to[n-1:1]&{(n-1){~sel[2]}};
    u1_b[0]=b_to[0]|sel[2];  
  end
  
  wire [3:0][n-1:0] logic_out;
  wire [3:0][n-1:0] arith_out;
  assign logic_out[0]=sel[0]?b_to:a_to;
  assign logic_out[1]=(a_to|b_to)^{n{&sel[1:0]}};
  assign logic_out[2]=(a_to&b_to)^{n{&sel[1:0]}};
  assign logic_out[3]=(a_to^b_to)^{n{&sel[1:0]}};

  assign arith_out[0]=u1_out[n-1:0];
  assign arith_out[1]=u0_out;
  assign arith_out[2]=sel[0]?{{16{a[15]}},a[15:0]}:{{24{a[7]}},a[7:0]};
  assign arith_out[3]=u1_out[n-1:0];
  
  always @* begin
    c=arith?arith_out[sel[3:2]]:logic_out[sel[3:2]];
    flags[0]=(c==0); //zero
    flags[1]=flags[3]?u1_out[n]:c[n-1]; //negative
    flags[2]=~(^sel[3:2])&u1_out[n]; //carry out
    flags[3]=~(^sel[3:2])&u1_overflow; //overflow
    flags[4]=^c; //parity </3..
  end
endmodule

//module adder #(parameter n=32) (input subtr, input cin, input signed [n-1:0] a, input signed [n-1:0] b, output reg signed [n:0] c, output reg overflow);
module adder #(parameter n=32) (input subtr, input cin, input [n-1:0] a, input [n-1:0] b, output reg [n:0] c, output reg overflow);
  reg cin_op;
  reg [n-1:0] b_op;
  always @* begin
    cin_op=subtr|cin;
    b_op=subtr?~b:b;
    c=a+b_op+cin_op;
    //if (subtr) c=a-b-cin;
    //else c=a+b+cin;
    overflow=(a[n-1]&b_op[n-1]&~c[n-1])|(~a[n-1]&~b_op[n-1]&c[n-1]); // could also be carry[n-1]^carry[n-2]
  end
endmodule

module shift_rotate (input left, input arith, input rotate, input [4:0] op, input [31:0] a, output [31:0] b);
  wire [4:0][31:0] r_sr_stage;
  wire [4:0][31:0] l_sr_stage;
  wire set_1;
  assign set_1=a[31]&arith;
  assign l_sr_stage[0]=op[0]?{a[30:0],a[31]&rotate}:a;
  assign l_sr_stage[1]=op[1]?{l_sr_stage[0][29:0],{ l_sr_stage[0][31:30] & {2{rotate}} }}:l_sr_stage[0];
  assign l_sr_stage[2]=op[2]?{l_sr_stage[1][27:0],{ l_sr_stage[1][31:28] & {4{rotate}} }}:l_sr_stage[1];
  assign l_sr_stage[3]=op[3]?{l_sr_stage[2][23:0],{ l_sr_stage[2][31:24] & {8{rotate}} }}:l_sr_stage[2];
  assign l_sr_stage[4]=op[4]?{l_sr_stage[3][15:0],{ l_sr_stage[3][31:16] & {16{rotate}} }}:l_sr_stage[3];

  assign r_sr_stage[0]=op[0]?{(a[31]&arith)|(a[0]&rotate),a[31:1]}:a;
  assign r_sr_stage[1]=op[1]?{ { {2{set_1}} | r_sr_stage[0][1:0] & {2{rotate}} },r_sr_stage[0][31:2]}:r_sr_stage[0];
  assign r_sr_stage[2]=op[2]?{ { {4{set_1}} | r_sr_stage[1][3:0] & {4{rotate}} },r_sr_stage[1][31:4]}:r_sr_stage[1];
  assign r_sr_stage[3]=op[3]?{ { {8{set_1}} | r_sr_stage[2][7:0] & {8{rotate}} },r_sr_stage[2][31:8]}:r_sr_stage[2];
  assign r_sr_stage[4]=op[4]?{ { {16{set_1}} | r_sr_stage[3][15:0] & {16{rotate}} },r_sr_stage[3][31:16]}:r_sr_stage[3];
  assign b=left?l_sr_stage[4]:r_sr_stage[4];
endmodule
