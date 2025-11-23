module memory (
 input clk,we_a,we_b,we_c,
 input [7:0] wd_a, wd_b, wd_c,
 input [10:0] addr_b, addr_c,
 input [18:0] addr_a,
 output reg [7:0] rd_a,rd_b, rd_c
);
  reg [255:0] decoder_out;
  always @* begin
    decoder_out=0;
    decoder_out[addr_a[18:11]]=1;
    rd_a=ebr_a0[addr_a[18:11]];
  end
  
  integer j;
  always @* begin
    for (j=0;j<memblks;j++) begin
      dia[j]={10'b0,wd_a};
      ada[j]={addr_a[10:0],3'b0};
      wea[j]=decoder_out[j]&we_a;
      //cea[j]=decoder_out[j];
      //ocea[j]=decoder_out[j];
      //csa[j]={3{decoder_out[j]}};
      cea[j]=1'b1;
      ocea[j]=1'b1;
      csa[j]=3'b111;
      rsta=0;
      if (j<memblks-2) begin
        dib[j]=0;
        adb[j]=0;
        web[j]=0;
        ceb[j]=0;
        oceb[j]=0;
        csb[j]=0;
        rstb=0;
      end
    end
  end
  always @* begin
    dib[memblks-2]={10'b0,wd_b};
    adb[memblks-2]={addr_b,3'b0};
    web[memblks-2]=we_b;
    ceb[memblks-2]=1;
    oceb[memblks-2]=1;
    csb[memblks-2]=3'b111;
    rstb[memblks-2]=0;
    rd_b=dob[memblks-2][7:0];
    //
    dib[memblks-1]={10'b0,wd_c};
    adb[memblks-1]={addr_c,3'b0};
    web[memblks-1]=we_c;
    ceb[memblks-1]=1;
    oceb[memblks-1]=1;
    csb[memblks-1]=3'b111;
    rstb[memblks-1]=0;
    rd_c=dob[memblks-1][7:0];
  end
  
  //localparam memblks=208;
  localparam memblks=3;
  reg [memblks-1:0][17:0] dia,dib;
  reg [memblks-1:0][13:0] ada,adb;
  reg [memblks-1:0][2:0] csa,csb;
  reg [memblks-1:0] cea,ceb;
  reg [memblks-1:0] ocea,oceb;
  reg [memblks-1:0] wea,web;
  reg [memblks-1:0] rsta,rstb;
  wire [memblks-1:0][17:0] doa,dob;
  wire [memblks-1:0][7:0] ebr_a0;
  genvar i;
  generate
    for (i=0;i<memblks;i++) begin
      DP16KD 
      #(
        .DATA_WIDTH_A(9),
        .DATA_WIDTH_B(9),
        .WRITEMODE_A("NORMAL"),
        .WRITEMODE_B("NORMAL"),
        .CSDECODE_A("0b111"),
        .CSDECODE_B("0b111"),
        .RESETMODE("ASYNC")
      )
      u1 (
        .DIA0(dia[i][0]), .DIA1(dia[i][1]), .DIA2(dia[i][2]), .DIA3(dia[i][3]), .DIA4(dia[i][4]), .DIA5(dia[i][5]), .DIA6(dia[i][6]), .DIA7(dia[i][7]), .DIA8(dia[i][8]), .DIA9(dia[i][9]), .DIA10(dia[i][10]), .DIA11(dia[i][11]), .DIA12(dia[i][12]), .DIA13(dia[i][13]), .DIA14(dia[i][14]), .DIA15(dia[i][15]), .DIA16(dia[i][16]), .DIA17(dia[i][17]),
        .ADA0(ada[i][0]), .ADA1(ada[i][1]), .ADA2(ada[i][2]), .ADA3(ada[i][3]), .ADA4(ada[i][4]), .ADA5(ada[i][5]), .ADA6(ada[i][6]), .ADA7(ada[i][7]), .ADA8(ada[i][8]), .ADA9(ada[i][9]), .ADA10(ada[i][10]), .ADA11(ada[i][11]), .ADA12(ada[i][12]), .ADA13(ada[i][13]),
        .CLKA(clk),
        .CEA(cea[i]),
        .OCEA(ocea[i]),
        .WEA(wea[i]),
        .CSA0(csa[i][0]),
        .CSA1(csa[i][1]),
        .CSA2(csa[i][2]),
        .RSTA(rsta[i]),

        .DIB0(dib[i][0]), .DIB1(dib[i][1]), .DIB2(dib[i][2]), .DIB3(dib[i][3]), .DIB4(dib[i][4]), .DIB5(dib[i][5]), .DIB6(dib[i][6]), .DIB7(dib[i][7]), .DIB8(dib[i][8]), .DIB9(dib[i][9]), .DIB10(dib[i][10]), .DIB11(dib[i][11]), .DIB12(dib[i][12]), .DIB13(dib[i][13]), .DIB14(dib[i][14]), .DIB15(dib[i][15]), .DIB16(dib[i][16]), .DIB17(dib[i][17]),
        .ADB0(adb[i][0]), .ADB1(adb[i][1]), .ADB2(adb[i][2]), .ADB3(adb[i][3]), .ADB4(adb[i][4]), .ADB5(adb[i][5]), .ADB6(adb[i][6]), .ADB7(adb[i][7]), .ADB8(adb[i][8]), .ADB9(adb[i][9]), .ADB10(adb[i][10]), .ADB11(adb[i][11]), .ADB12(adb[i][12]), .ADB13(adb[i][13]),
        .CLKB(clk),
        .CEB(ceb[i]),
        .OCEB(oceb[i]),
        .WEB(web[i]),
        .CSB0(csb[i][0]),
        .CSB1(csb[i][1]),
        .CSB2(csb[i][2]),
        .RSTB(rstb[i]),

        .DOA0(doa[i][0]), .DOA1(doa[i][1]), .DOA2(doa[i][2]), .DOA3(doa[i][3]), .DOA4(doa[i][4]), .DOA5(doa[i][5]), .DOA6(doa[i][6]), .DOA7(doa[i][7]), .DOA8(doa[i][8]), .DOA9(doa[i][9]), .DOA10(doa[i][10]), .DOA11(doa[i][11]), .DOA12(doa[i][12]), .DOA13(doa[i][13]), .DOA14(doa[i][14]), .DOA15(doa[i][15]), .DOA16(doa[i][16]), .DOA17(doa[i][17]),
        .DOB0(dob[i][0]), .DOB1(dob[i][1]), .DOB2(dob[i][2]), .DOB3(dob[i][3]), .DOB4(dob[i][4]), .DOB5(dob[i][5]), .DOB6(dob[i][6]), .DOB7(dob[i][7]), .DOB8(dob[i][8]), .DOB9(dob[i][9]), .DOB10(dob[i][10]), .DOB11(dob[i][11]), .DOB12(dob[i][12]), .DOB13(dob[i][13]), .DOB14(dob[i][14]), .DOB15(dob[i][15]), .DOB16(dob[i][16]), .DOB17(dob[i][17]),
      );
      assign ebr_a0[i]=doa[i][7:0];
    end
  endgenerate
endmodule
