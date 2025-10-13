module main (input i_clk, input rx, input [1:0] btn, input [7:0] dip, output tx, output reg [7:0] led);
  localparam CLK_FREQ=50_000_000;
  wire clk;
  clk12_to_50 u_clk (i_clk,clk);
  //localparam CLK_FREQ=12_000_000;
  //wire clk=i_clk;

  reg state=0, prev_btn0=0;
  always @(posedge clk) begin
    prev_btn0<=btn[0];
    if (prev_btn0 && !btn[0] || u2_cede || cpu_cede) state<=~state;
  end
  reg u0_ready;
  reg [7:0] u0_data;
  uart_r #(.CLK_FREQ(CLK_FREQ)) u0 (clk,rx,u0_ready,u0_data);

  reg u1_en,u1_ready;
  reg [7:0] u1_data;
  uart_t #(.CLK_FREQ(CLK_FREQ), .WAIT_BEFORE_SAMPLING(1)) u1 (clk,u1_en,u1_data,u1_ready,tx);
  always @* begin
    case (state || uart_state!=0)
      0:begin
        u1_en=u2_tx_en;
        u1_data=u2_tx_data;
        u3_wea=u2_we;
        u3_dia=u2_di;
        u3_ada=u2_ad;
      end
      1:begin
        u1_en=uart_tx_en;
        u1_data=uart_tx_data;
        u3_wea=cpu_we;
        u3_dia=cpu_di;
        u3_ada=cpu_ad;
      end
    endcase
  end
  localparam UART_BASE=11'h600;
  localparam STORE_OFFSET=11'd256;
  reg uart_tx_en=0;
  reg [1:0] uart_r_stg=0,uart_tx_stg=0;
  reg [7:0] dib=0,uart_tx_data=0,rcvd_data=0,rcvd_cnt=0;
  reg [10:0] adb=UART_BASE,uart_len=0;
  reg [3:0] uart_state=0;
  reg u3_web=0;
  always @* u3_dib={10'b0,dib};
  
  // this thing below is a uart interface for the cpu
  // as it stands it can store up to 256 received bytes on memory before starting to overwrite them, beggining at address UART_BASE+STORE_OFFSET
  // it can also send up to 252 ( 256 minus a control word :c ) bytes on one command
  // so it takes up the last 512 bytes of memory
  // byte at address UART_BASE is the send flag. if set to one by the cpu, the controller will then look at byte UART_BASE+3 and take it as transfer size
  // it will then transfer data starting at UART_BASE+4
  // whenever data is received during runtime, the controller sets the received flag (UART_BASE+1) to one, if not already set
  // after that the received counter (byte UART_BASE+2) is read, 
  // the data is stored at UART_BASE+STORE_OFFSET+[received counter], and the counter is incremented
  // (the cpu may set the received flag or received counter to whatever value seen as fit, 
  //  for example both to 0 to start overwritting received data and be able to tell when new transfers have been received)

  // tx_en must be asserted for two clock cycles
  // tx_data is sampled at the second
  // u3_web can be asserted for only one clock cycle
  // u3_dob is updated two clock cycles after an address change (one is to sample the new address, the other is to output its value)
  always @(posedge clk) begin
    if ( (state && (u3_dob[0] || u0_ready)) || uart_state!=0 ) begin
      if (uart_state==0) begin
        if (u3_dob[0]) begin
          uart_tx_en<=0;
          dib<=0;
          u3_web<=1;
          
          uart_state<=1;
        end
        else if (u0_ready) begin
          uart_tx_en<=0;
          dib<=1;
          u3_web<=1;
          adb<=adb+1;
          
          rcvd_data<=u0_data;

          uart_state<=8;
        end
      end
      else if (uart_state==1) begin
        u3_web<=0;
        adb<=adb+3;
        uart_state<=2;
      end
      else if (uart_state===2) begin
        adb<=adb+1;
        uart_state<=3;
      end
      else if (uart_state==3) begin
        uart_len[7:0]<=u3_dob[7:0];
        uart_tx_en<=1;
        uart_state<=4;
      end
      else if (uart_state==4) begin
        if (uart_len!=0) begin
          adb<=adb+1;
          uart_tx_data<=u3_dob[7:0];
          uart_tx_en<=1;
          uart_state<=5;
          uart_len<=uart_len-1;
        end
        else begin
          adb<=UART_BASE;
          uart_tx_en<=0;
          uart_state<=0;
        end
      end
      else if (uart_state==5) begin
        if (uart_len!=0) begin
          if (u1_ready) begin
            adb<=adb+1;
            uart_tx_data<=u3_dob[7:0];
            uart_len<=uart_len-1;
          end
        end
        else begin
          uart_state<=7;
        end
      end
      else if (uart_state==7) begin
        uart_state<=0;
        uart_tx_en<=0;
        adb<=UART_BASE;
      end
      //
      else if (uart_state==8) begin
        u3_web<=0;
        adb<=adb+1;
        uart_state<=9;
      end
      else if (uart_state==9) begin
        u3_web<=0;
        uart_state<=10;
      end
      else if (uart_state==10) begin
        u3_web<=1;
        dib<=u3_dob[7:0]+1;
        rcvd_cnt<=u3_dob[7:0];
        uart_state<=11;
      end
      else if (uart_state==11) begin
        u3_web<=0;
        adb<=adb+(STORE_OFFSET-2)+u3_dob[7:0];
        uart_state<=12;
      end
      else if (uart_state==12) begin
        uart_state<=13;
      end
      else if (uart_state==13) begin
        u3_web<=1;
        dib<=rcvd_data;
        uart_state<=14;
      end
      else if (uart_state==14) begin
        u3_web<=0;
        adb<=UART_BASE;
        uart_state<=15;
      end
      else if (uart_state==15) begin
        uart_state<=7;
      end
    end
  end

  reg u2_we,u2_tx_en,u2_cede;
  wire [4:0] u2_ra1;
  wire [7:0] u2_tx_data;
  wire [13:0] u2_ad;
  wire [17:0] u2_di;

  memmgr u2 (
    /*btn,dip,*/
    clk,
    state,
    u0_ready,
    u0_data,
    u3_doa,
    u4_rd1,
    u1_ready,
    u2_we,
    u2_tx_en,
    u2_cede,
    u2_ra1,
    u2_tx_data,
    u2_ad,
    u2_di
    /*,led*/
  );
  
  reg u3_wea,u3_web=0;
  reg [17:0] u3_dia,u3_dib;
  reg [13:0] u3_ada,u3_adb={adb,3'b0};
  wire [17:0] u3_doa,u3_dob;
  DP16KD #(
    .REGMODE_A("NOREG"),
    .DATA_WIDTH_A(9),
    .DATA_WIDTH_B(9),
    .WRITEMODE_A("WRITETHROUGH"),
    .CSDECODE_A("0b111"), 
    .CSDECODE_B("0b111"), 
  ) u3_ebr (
    .DIA0(u3_dia[0]), //18
    .DIA1(u3_dia[1]),
    .DIA2(u3_dia[2]),
    .DIA3(u3_dia[3]),
    .DIA4(u3_dia[4]),
    .DIA5(u3_dia[5]),
    .DIA6(u3_dia[6]),
    .DIA7(u3_dia[7]),
    .DIA8(u3_dia[8]),
    .DIA9(u3_dia[9]),
    .DIA10(u3_dia[10]),
    .DIA11(u3_dia[11]),
    .DIA12(u3_dia[12]),
    .DIA13(u3_dia[13]),
    .DIA14(u3_dia[14]),
    .DIA15(u3_dia[15]),
    .DIA16(u3_dia[16]),
    .DIA17(u3_dia[17]),

    .ADA0(u3_ada[0]), //14     
    .ADA1(u3_ada[1]),
    .ADA2(u3_ada[2]), 
    .ADA3(u3_ada[3]),
    .ADA4(u3_ada[4]),
    .ADA5(u3_ada[5]),
    .ADA6(u3_ada[6]),
    .ADA7(u3_ada[7]),
    .ADA8(u3_ada[8]),
    .ADA9(u3_ada[9]),
    .ADA10(u3_ada[10]),
    .ADA11(u3_ada[11]),
    .ADA12(u3_ada[12]),
    .ADA13(u3_ada[13]),
    
    .CEA(1'b1),
    .OCEA(1'b1),
    .CLKA(clk),
    .WEA(u3_wea),
    .CSA0(1'b1), //3
    .CSA1(1'b1), 
    .CSA2(1'b1), 
    .RSTA(1'b0),
    
    .DIB0(u3_dib[0]), //18
    .DIB1(u3_dib[1]),
    .DIB2(u3_dib[2]),
    .DIB3(u3_dib[3]),
    .DIB4(u3_dib[4]),
    .DIB5(u3_dib[5]),
    .DIB6(u3_dib[6]),
    .DIB7(u3_dib[7]),
    .DIB8(u3_dib[8]),
    .DIB9(u3_dib[9]),
    .DIB10(u3_dib[10]),
    .DIB11(u3_dib[11]),
    .DIB12(u3_dib[12]),
    .DIB13(u3_dib[13]),
    .DIB14(u3_dib[14]),
    .DIB15(u3_dib[15]),
    .DIB16(u3_dib[16]),
    .DIB17(u3_dib[17]),
    .ADB0(u3_adb[0]), //14     
    .ADB1(u3_adb[1]),
    .ADB2(u3_adb[2]), 
    .ADB3(u3_adb[3]),
    .ADB4(u3_adb[4]),
    .ADB5(u3_adb[5]),
    .ADB6(u3_adb[6]),
    .ADB7(u3_adb[7]),
    .ADB8(u3_adb[8]),
    .ADB9(u3_adb[9]),
    .ADB10(u3_adb[10]),
    .ADB11(u3_adb[11]),
    .ADB12(u3_adb[12]),
    .ADB13(u3_adb[13]),

    .CEB(1'b1),
    .OCEB(1'b1),
    .CLKB(clk),
    .WEB(u3_web),
    .CSB0(1'b1), //3
    .CSB1(1'b1), //3
    .CSB2(1'b1), //3
    .RSTB(1'b0),

    .DOA0(u3_doa[0]), //18
    .DOA1(u3_doa[1]),
    .DOA2(u3_doa[2]),
    .DOA3(u3_doa[3]),
    .DOA4(u3_doa[4]),
    .DOA5(u3_doa[5]),
    .DOA6(u3_doa[6]),
    .DOA7(u3_doa[7]),
    .DOA8(u3_doa[8]),
    .DOA9(u3_doa[9]),
    .DOA10(u3_doa[10]),
    .DOA11(u3_doa[11]),
    .DOA12(u3_doa[12]),
    .DOA13(u3_doa[13]),
    .DOA14(u3_doa[14]),
    .DOA15(u3_doa[15]),
    .DOA16(u3_doa[16]),
    .DOA17(u3_doa[17]),

    .DOB0(u3_dob[0]), //18
    .DOB1(u3_dob[1]),
    .DOB2(u3_dob[2]),
    .DOB3(u3_dob[3]),
    .DOB4(u3_dob[4]),
    .DOB5(u3_dob[5]),
    .DOB6(u3_dob[6]),
    .DOB7(u3_dob[7]),
    .DOB8(u3_dob[8]),
    .DOB9(u3_dob[9]),
    .DOB10(u3_dob[10]),
    .DOB11(u3_dob[11]),
    .DOB12(u3_dob[12]),
    .DOB13(u3_dob[13]),
    .DOB14(u3_dob[14]),
    .DOB15(u3_dob[15]),
    .DOB16(u3_dob[16]),
    .DOB17(u3_dob[17]),

  );
  
  localparam init_addr=11'h00;
  reg [2:0] r_stg=0,n_r_stg,instr_stg=0;
  reg [3:0] cpu_state=0,n_cpu_state,n_instr_stg;
  reg [13:0] cpu_ad;
  reg [31:0] instr=0,rmem=0;
  reg instr_we,cpu_cede,rmem_rst,rmem_we,cpu_we;
  reg [1:0] sel_cpu_ada,sel_instr,sel_rmem,sel_di;
  reg [10:0] cpu_ada,n_cpu_ada;
  reg [7:0] cpu_di;
  always @* begin
    cpu_ad={cpu_ada,3'b0};
    n_cpu_ada=sel_cpu_ada[1]?
      (sel_cpu_ada[0]?cpu_ada:u4_pc_in):
      (sel_cpu_ada[0]?cpu_ada+1:init_addr);
    // 00:init_addr 01:cpu_ada+1 10:u4_pc_in 11:alu
    cpu_di=sel_di[1]?
      (sel_di[0]?temp[31:24]:temp[23:16]):
      (sel_di[0]?temp[15:8]:temp[7:0]);
  end

  always @(posedge clk) begin
    cpu_state<=n_cpu_state;
    instr_stg<=n_instr_stg;
    r_stg<=n_r_stg;
    cpu_ada<=n_cpu_ada;
    if (instr_we) 
      if (sel_instr==0) instr[7:0]<=u3_doa[7:0];
      else if (sel_instr==1) instr[15:8]<=u3_doa[7:0];
      else if (sel_instr==2) instr[23:16]<=u3_doa[7:0];
      else if (sel_instr==3) instr[31:24]<=u3_doa[7:0];
    if (rmem_rst) rmem<=0;
    else if (rmem_we)
      if (sel_rmem==0) rmem[7:0]<=u3_doa[7:0];
      else if (sel_rmem==1) rmem[15:8]<=u3_doa[7:0];
      else if (sel_rmem==2) rmem[23:16]<=u3_doa[7:0];
      else if (sel_rmem==3) rmem[31:24]<=u3_doa[7:0];
  end

  always @* begin
    n_cpu_state=cpu_state;
    n_instr_stg=instr_stg;
    n_r_stg=r_stg;
    sel_cpu_ada=2'b11;
    sel_instr=2'b00;
    sel_rmem=2'b00;
    rmem_we = 1'b0;
    rmem_rst= 1'b0;
    instr_we=0;
    cpu_cede=0;
    cpu_we=0;
    sel_di=0;
    case (state)
      0:begin
        n_cpu_state=0;
        n_instr_stg=0;
        n_r_stg=0;
      end
      1:case (cpu_state)
        0:begin
          n_cpu_state=1;
          sel_cpu_ada=0;
        end
        1:case (r_stg)
          0:begin
            n_r_stg=1;
            sel_cpu_ada=1;
          end
          1:begin
            n_r_stg=2;
            sel_cpu_ada=1;
            instr_we=1;
            sel_instr=0;
          end
          2:begin
            n_r_stg=3;
            sel_cpu_ada=1;
            instr_we=1;
            sel_instr=1;
          end
          3:begin
            n_r_stg=4;
            sel_cpu_ada=1;
            instr_we=1;
            sel_instr=2;
          end
          4:begin
            n_r_stg=0;
            n_cpu_state=2;
            instr_we=1;
            sel_instr=3;
          end
        endcase
        2:case (instr[6:0])
          7'b1100111:case (instr_stg) //jalr
            0:n_instr_stg=1;
            1:n_instr_stg=2;
            2:begin
              n_instr_stg=0;
              n_cpu_state=1;
              sel_cpu_ada=2;
            end
          endcase
          //
          7'b1100011:case (instr[14:12])
            default:case (instr_stg) //all branch instructions
              0:n_instr_stg=1; //load flags to temp
              1:begin //set new pc accordingly
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
          endcase
          //
          7'b0000011:case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin // load address to cpu_ada
                rmem_rst=1;
                sel_cpu_ada=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: n_instr_stg=5; // load to rd
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin // load address to cpu_ada
                rmem_rst=1;
                sel_cpu_ada=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: n_instr_stg=3; //wait for output
              3:begin //load to rmem
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin // load address to cpu_ada
                rmem_rst=1;
                sel_cpu_ada=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ada=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: n_instr_stg=6; // load to rd
              6: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin // load address to cpu_ada
                rmem_rst=1;
                sel_cpu_ada=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ada=1;
                n_instr_stg=3;
              end
              3:begin //load lower byte
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
              end
              4:begin //load upper byte
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
              end
              5: begin //load with sign extension to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin // load address to cpu_ada
                rmem_rst=1;
                sel_cpu_ada=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ada=1;
                n_instr_stg=3;
              end
              3:begin //load first byte and increment again
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
                sel_cpu_ada=1;
              end
              4:begin //load second byte and increment again
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
                sel_cpu_ada=1;
              end
              5:begin //load third byte
                rmem_we=1;
                sel_rmem=2;
                n_instr_stg=6;
              end
              6:begin //load last byte
                rmem_we=1;
                sel_rmem=3;
                n_instr_stg=7;
              end
              7: begin //load to rd
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ada
                sel_cpu_ada=2;
                n_instr_stg=2;
              end
              2:begin //store
                cpu_we=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b001:case (instr_stg) //sh
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ada
                sel_cpu_ada=2;
                n_instr_stg=2;
              end
              2:begin //store first byte and increment
                cpu_we=1;
                n_instr_stg=3;
                sel_cpu_ada=1;
              end
              3:begin //store second byte
                cpu_we=1;
                sel_di=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ada
                sel_cpu_ada=2;
                n_instr_stg=2;
              end
              2:begin //store first byte
                cpu_we=1;
                n_instr_stg=3;
                sel_cpu_ada=1;
              end
              3:begin //store second byte
                cpu_we=1;
                sel_di=1;
                n_instr_stg=4;
                sel_cpu_ada=1;
              end
              4:begin //store third byte
                cpu_we=1;
                sel_di=2;
                n_instr_stg=5;
                sel_cpu_ada=1;
              end
              5:begin //store last byte
                cpu_we=1;
                sel_di=3;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ada=2;
              end
            endcase
          endcase
          7'b0:begin
            cpu_cede=1;
          end
          default:begin // unspecified instructions are assumed to take 1 cycle
            n_cpu_state=1;
            sel_cpu_ada=2;
          end
        endcase
      endcase
    endcase
  end
   
    always @* begin
      u4_we     = 1'b0;
      u4_pc_we  = 1'b0;
      wd_sel    = 3'b000;
      pc_sel    = 2'b00;
      a_sel     = 2'b0;
      b_sel     = 2'b0;
      u5_arith  = 1'b0;
      u5_sel    = 4'b0000;
      u5_cin    = 1'b0;
      format    = 3'd0;
      temp_sel  = 0;
      temp_we   = 0;
      u4_ra1    = instr[19:15];
      u4_ra2    = instr[24:20];
      u4_wa     = instr[11:7];
      case (cpu_state)
        0:begin
          pc_sel[0]=state[0];
          u4_pc_we=state[0];
          u4_ra1=u2_ra1;
        end
        2:case (instr[6:0])
          7'b0110111: begin //lui
            format=3;
            b_sel=1;
            u5_sel=4'b0011;
            u4_we=1;
            u4_pc_we=1;
          end
          7'b0010111:begin //auipc
            format=3;
            a_sel=1;
            b_sel=1;
            u5_arith=1;
            u4_we=1;
            u4_pc_we=1;
          end
          7'b1101111:begin // jal
            format=4;
            a_sel=1;
            b_sel=1;
            u5_arith=1;
            u5_sel=0;     // alu=pc+imm
            wd_sel=2'b10; // wd=alu+4
            pc_sel=2'b11; // pc=alu
            u4_we=1;
            u4_pc_we=1;
          end
          7'b1100111: case (instr_stg) //jalr
            0:begin // temp<={{31{1'b1}},1'b0} mayhaps it's a little wasteful to compute a constant within an instruction
              a_sel=0;
              u4_ra1=5'd0;
              u5_arith=1;
              u5_sel=4'b1111;
              temp_we=1;
            end
            1:begin // rd<=rs1+imm;
              format=0;
              a_sel=0;
              b_sel=1;
              u5_arith=1;
              u5_sel=0;
              u4_we=1;
            end
            2:begin //rd<=(rd&temp)+4;pc<=(rd&temp);
              a_sel=0;
              u4_ra1=instr[11:7];
              b_sel=2'b10;
              u5_arith=0;
              u5_sel=4'b1000;
              pc_sel=2'b11; // pc_in=alu;
              wd_sel=2'b10; // wd=pc_next (alu+4)
              u4_we=1;
              u4_pc_we=1;
            end
          endcase
          //
          7'b1100011: case (instr[14:12])
            0:case (instr_stg) //beq
              0:begin
                u5_arith=1;
                u5_sel=4'b0011; //rs1-rs2
                temp_sel=1; //flags
                temp_we=1;
                //u4_pc_we=1;
              end            
              1:if (temp[0]) begin // if zero (eq)
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
                else begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
            endcase
            3'b1:case (instr_stg) //bne
              0:begin
                u5_arith=1;
                u5_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[0]) begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
            endcase
            3'b100:case (instr_stg) //blt
              0:begin
                u5_arith=1;
                u5_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[1]) begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
                else begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
            endcase
            3'b110:case (instr_stg) //bltu
              0:begin
                u5_arith=1;
                u5_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[2]) begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
            endcase
            3'b101:case (instr_stg) //bge
              0:begin
                u5_arith=1;
                u5_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[1]) begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
                else begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
            endcase
            3'b111:case (instr_stg) //bgeu
              0:begin
                u5_arith=1;
                u5_sel=4'b0011;
                temp_sel=1;
                temp_we=1;
              end
              1:if (temp[2]) begin
                  format=2;
                  a_sel=1; 
                  b_sel=1;
                  u5_arith=1;
                  u5_sel=0;
                  pc_sel=2'b11;
                  u4_pc_we=1;
                end
                else begin
                  u4_pc_we=1;
                  pc_sel=0;                  
                end
            endcase
          endcase
          //
          7'b0000011: case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin
                format=0; //I
                b_sel=1;
                u5_arith=1;
                u5_sel=0; // rs1+imm
                pc_sel=2'b11; //pass alu to cpu_ada
              end
              4:begin
                wd_sel=1;
                u4_we=1;
              end
              5:begin
                u4_ra1=instr[11:7];
                u5_arith=1;
                u5_sel=4'b1000;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin
                format=0; //I
                b_sel=1;
                u5_arith=1;
                u5_sel=0; // rs1+imm
                pc_sel=2'b11; //pass alu to cpu_ada
              end
              4:begin
                wd_sel=1;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin
                format=0; //I
                b_sel=1;
                u5_arith=1;
                u5_sel=0; // rs1+imm
                pc_sel=2'b11; //pass alu to cpu_ada
              end
              5:begin
                wd_sel=1;
                u4_we=1;
              end
              6:begin
                u4_ra1=instr[11:7];
                u5_arith=1;
                u5_sel=4'b1001;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin
                format=0; //I
                b_sel=1;
                u5_arith=1;
                u5_sel=0; // rs1+imm
                pc_sel=2'b11; //pass alu to cpu_ada
              end
              5:begin
                wd_sel=1;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin
                format=0; //I
                b_sel=1;
                u5_arith=1;
                u5_sel=0; // rs1+imm
                pc_sel=2'b11; //pass alu to cpu_ada
              end
              7:begin
                wd_sel=1;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0:begin
                u5_arith=0;
                u5_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                u5_arith=1;
                u5_sel=0;
                pc_sel=2'b11;
              end
              2:begin
                u4_pc_we=1;
              end
            endcase
            3'b1:case (instr_stg) //sh
              0:begin
                u5_arith=0;
                u5_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                u5_arith=1;
                u5_sel=0;
                pc_sel=2'b11;
              end
              3:begin
                u4_pc_we=1;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0:begin
                u5_arith=0;
                u5_sel=4'b0011;
                temp_we=1;
              end
              1:begin
                format=1;
                b_sel=1;
                u5_arith=1;
                u5_sel=0;
                pc_sel=2'b11;
              end
              5:begin
                u4_pc_we=1;
              end
            endcase
          endcase
          7'b0010011: case (instr[14:12])
            3'b0:begin //addi
              format=0;
              a_sel=0;
              b_sel=1;
              u5_arith=1;
              u5_sel=0;
              wd_sel=0;
              u4_we=1;
              pc_sel=0;
              u4_pc_we=1;
            end
            3'b010:begin //slti
              format=0;
              b_sel=1;
              u5_arith=1;
              u5_sel=4'b0011;
              wd_sel=3'b100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b011:begin //sltiu
              format=0;
              b_sel=1;
              u5_arith=1;
              u5_sel=4'b0011;
              wd_sel=3'b101;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b100:begin //xori
              format=0;
              b_sel=1;
              u5_sel=4'b1100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b110:begin //ori
              format=0;
              b_sel=1;
              u5_sel=4'b0100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b111:begin //andi
              format=0;
              b_sel=1;
              u5_sel=4'b1000;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b001:begin //slli
              b_sel=1;
              u5_arith=1;
              u5_sel=4'b0110;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b101:case (instr[30])
              0:begin //srli
                b_sel=1;
                u5_arith=1;
                u5_sel=4'b0100;
                u4_we=1;
                u4_pc_we=1;
              end
              1:begin //srai
                b_sel=1;
                u5_arith=1;
                u5_cin=1;
                u5_sel=4'b0100;
                u4_we=1;
                u4_pc_we=1;                
              end
            endcase
          endcase
          7'b0110011: case (instr[14:12])
            3'b0: case (instr[30])
              0:begin //add
                u5_arith=1;
                u4_we=1;
                u4_pc_we=1;
              end
              1:begin //sub
                u5_arith=1;
                u5_sel=4'b0011;
                u4_we=1;
                u4_pc_we=1;
              end
            endcase
            3'b1:begin //sll
              u5_arith=1;
              u5_sel=4'b0110;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b010:begin //slt
              u5_arith=1;
              u5_sel=4'b0011;
              wd_sel=3'b100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b011:begin //sltu
              u5_arith=1;
              u5_sel=4'b0011;
              wd_sel=3'b101;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b100:begin //xor
              u5_sel=4'b1100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b101:if (!instr[30]) begin //srl
              u5_arith=1;
              u5_sel=4'b0100;
              u4_we=1;
              u4_pc_we=1;
            end
            else begin //sra
              u5_arith=1;
              u5_cin=1;
              u5_sel=4'b0100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b110:begin //or
              u5_sel=4'b0100;
              u4_we=1;
              u4_pc_we=1;
            end
            3'b111:begin //and
              u5_sel=4'b1000;
              u4_we=1;
              u4_pc_we=1;
            end
          endcase
          //7'd1:begin //made up instruction to load imm I to x1
          //  format=2;
          //  u4_wa=5'd1;
          //  b_sel=1; //imm
          //  u5_arith=0;
          //  u5_sel=4'b0011; //passthrough b
          //  u4_pc_we=1;
          //  u4_we=1;
          //end
          //7'd2:begin //made up instruction to load flags of rs1-rs2 to x1
          //  u4_wa=5'd1;
          //  u5_arith=1;
          //  u5_sel=4'b0011; //subtract
          //  wd_sel=1; //flags
          //  u4_pc_we=1;
          //  u4_we=1;
          //end
          //7'd3:begin //made up instruction to load temp to x1
          //  u4_wa=5'd1;
          //  wd_sel=2'b11; 
          //  u4_we=1;
          //  u4_pc_we=1;
          //end
          //7'd127:begin // made up instruction to load rmem to x1
          //  u4_wa=5'd1;
          //  wd_sel=1; 
          //  u4_we=1;
          //  u4_pc_we=1;
          //end
          7'd0:begin
            //u4_ra1=5'b1;
          end
        endcase
      endcase
    end
    

    reg [2:0] format;
    reg [31:0] imm;
    always @* begin
      imm=0;
      case (format)
          0: imm={{20{instr[31]}},instr[31:20]}; //I
          1: imm={{20{instr[31]}},instr[31:25],instr[11:7]}; //S
          2: imm={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0}; //B
          3: imm={instr[31:12],12'b0}; //U
          4: imm={{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0}; //J
      endcase
    end

    reg u4_we,u4_pc_we;
    reg [4:0] u4_ra1,u4_ra2,u4_wa;
    reg [31:0] u4_pc_in,u4_wd;
    reg [31:0] u4_rd1,u4_rd2;
    reg [31:0] u4_pc_out;
    register_file u4 (
      clk,
      u4_we,
      u4_pc_we,
      u4_ra1,
      u4_ra2,
      u4_wa,
      u4_pc_in,
      u4_wd,
      u4_rd1,
      u4_rd2,
      u4_pc_out
    );
    reg flag_val,read_x1;
    reg [1:0] pc_sel;
    reg [2:0] flags_sel,wd_sel;
    reg [31:0] branch_val=0,pc_next;
    always @* begin
      u4_wd=
        wd_sel[2]?(wd_sel[0]?{31'b0,~u5_flags[2]}:u5_flags[1]):
        wd_sel[1]?
          (wd_sel[0]?temp:pc_next):
          (wd_sel[0]?rmem:u5_c);
      // wd: 000:alu; 001:rmem; 010:pc_next; 011:temp; 1x0:negative 1x1:~carry 
      
      pc_next=(pc_sel[1]?u5_c:u4_pc_out)+4;
      u4_pc_in=pc_sel[1]?
        (pc_sel[0]?u5_c:pc_next):
        (pc_sel[0]?init_addr:pc_next);
      // pc_in: 00:pc_out+4; 01:init_addr; 10:alu+4; 11:alu
    end
    reg temp_we,temp_sel;
    reg [31:0] temp;
    always @(posedge clk)
      if (temp_we) temp<=temp_sel?u5_flags:u5_c;

    reg u5_cin,u5_arith;
    reg [3:0] u5_sel;
    reg [31:0] u5_a,u5_b;
    reg [4:0] u5_flags;
    reg [31:0] u5_c;
    // ts alu is pretty retarded, it generates the only warnings on the source code. improve source
    alu u5 (
      u5_cin,
      u5_arith,
      u5_sel,
      u5_a,
      u5_b,
      u5_flags,
      u5_c
    );
    reg [1:0] b_sel,a_sel;
    always @* begin
      u5_a=a_sel[1]?temp:(a_sel[0]?u4_pc_out:u4_rd1);
      // 00: rd1; 01: pc; 1x:temp
      u5_b=b_sel[1]?temp:(b_sel[0]?imm:u4_rd2);
      // 00: rd2; 01: imm; 1x:temp;
    end

    always @* led=255;

endmodule
module register_file (input clk, input we, pc_we, input [4:0] ra1, ra2, wa, input [31:0] pc_in, wd, output reg [31:0] rd1, rd2, pc_out);
  (* ram_style = "logic" *) 
  reg [31:0] x [31:0];
  reg [31:0] pc;
  always @(posedge clk) begin
    if (we) if (wa!=0) x[wa]<=wd;
    if (pc_we) pc<=pc_in; 
  end
  always @* begin
    rd1=x[ra1];
    rd2=x[ra2];
    pc_out=pc;
  end
endmodule
