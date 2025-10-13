module main (input i_clk, input rx, input [1:0] btn, input [7:0] dip, output tx, output reg [7:0] led);
  localparam CLK_FREQ=50_000_000;
  wire clk;
  clk12_to_50 u_clk (i_clk,clk);
  //localparam CLK_FREQ=12_000_000;
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
  reg u0_ready;
  reg [7:0] u0_data;
  uart_r #(.CLK_FREQ(CLK_FREQ)) u0 (clk,rx,u0_ready,u0_data);

  reg u1_en,u1_ready;
  reg [7:0] u1_data=0;
  uart_t #(.CLK_FREQ(CLK_FREQ), .WAIT_BEFORE_SAMPLING(1)) u1 (clk,u1_en,u1_data,u1_ready,tx);
  
  always @* begin
    case (state || uart_state!=0)
      0:begin
        u1_en=u2_tx_en;
        u1_data=u2_tx_data;
        u3_wea=u2_we;
        u3_wda=u2_di;
        u3_ada=u2_ad;
        u3_web=web;
        u3_wdb=wdb;
        u3_adb=adb;
      end
      1:begin
        u1_en=uart_tx_en;
        u1_data=uart_tx_data;
        u3_wea=cpu_we;
        u3_wda=cpu_wd;
        u3_ada=cpu_ad;
        u3_web=web;
        u3_wdb=wdb;
        u3_adb=adb;
      end
    endcase
  end
  
  ///*
  localparam bmabl=11;
  localparam UART_BASE=11'h0;
  localparam STORE_OFFSET=11'd1024;
  reg uart_tx_en=0;
  reg [1:0] uart_r_stg=0,uart_tx_stg=0;
  reg [7:0] wdb=0,uart_tx_data=0,rcvd_data=0,rcvd_cnt=0;
  reg [bmabl-1:0] adb=UART_BASE,uart_len=0;
  reg [3:0] uart_state=0;
  reg web=0;
  reg [7:0] rdb=u3_rdb;

  // (now 1024 each)
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
  /*
  always @(posedge clk) begin
    if ( (state && (rdb[0] || u0_ready)) || uart_state!=0 ) begin
      if (uart_state==0) begin
        if (rdb[0]) begin
          uart_tx_en<=0;
          wdb<=0;
          web<=1;
          
          uart_state<=1;
        end
        else if (u0_ready) begin
          uart_tx_en<=0;
          wdb<=1;
          web<=1;
          adb<=adb+1;
          
          rcvd_data<=u0_data;

          uart_state<=8;
        end
      end
      else if (uart_state==1) begin
        web<=0;
        adb<=adb+3;
        uart_state<=2;
      end
      else if (uart_state===2) begin
        adb<=adb+1;
        uart_state<=3;
      end
      else if (uart_state==3) begin
        uart_len[7:0]<=rdb[7:0];
        uart_tx_en<=1;
        uart_state<=4;
      end
      else if (uart_state==4) begin
        if (uart_len!=0) begin
          adb<=adb+1;
          uart_tx_data<=rdb[7:0];
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
            uart_tx_data<=rdb[7:0];
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
        web<=0;
        adb<=adb+1;
        uart_state<=9;
      end
      else if (uart_state==9) begin
        web<=0;
        uart_state<=10;
      end
      else if (uart_state==10) begin
        web<=1;
        wdb<=rdb[7:0]+1;
        rcvd_cnt<=rdb[7:0];
        uart_state<=11;
      end
      else if (uart_state==11) begin
        web<=0;
        adb<=adb+(STORE_OFFSET-2)+rdb[7:0];
        uart_state<=12;
      end
      else if (uart_state==12) begin
        uart_state<=13;
      end
      else if (uart_state==13) begin
        web<=1;
        wdb<=rcvd_data;
        uart_state<=14;
      end
      else if (uart_state==14) begin
        web<=0;
        adb<=UART_BASE;
        uart_state<=15;
      end
      else if (uart_state==15) begin
        uart_state<=7;
      end
    end
  end
  //*/

  localparam mabl=19;
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
    u4_rd1,
    u1_ready,
    u2_we,
    u2_tx_en,
    u2_cede,
    u2_ra1,
    u2_tx_data,
    u2_ad,
    u2_di
    ,btn
    //,btn,dip,led
  );
  
  reg u3_wea,u3_web;
  reg [7:0] u3_wda,u3_wdb;
  reg [mabl-1:0] u3_ada;
  reg [10:0] u3_adb=0;
  wire [7:0] u3_rda,u3_rdb;
  
  memory u3 (
    .clk(clk),
    .we_a(u3_wea),
    .we_b(u3_web),
    .wd_a(u3_wda[7:0]),
    .wd_b(u3_wdb[7:0]),
    .addr_a(u3_ada),
    .addr_b(u3_adb),
    .rd_a(u3_rda[7:0]),
    .rd_b(u3_rdb[7:0])
  );
  
  localparam init_addr=19'h00;
  reg [2:0] r_stg=0,n_r_stg,instr_stg=0,n_instr_stg;
  reg [3:0] cpu_state=0,n_cpu_state;
  reg [31:0] instr=0,rmem=0;
  reg instr_we,cpu_cede,rmem_rst,rmem_we,cpu_we;
  reg [1:0] sel_cpu_ad,sel_instr,sel_rmem,sel_di;
  reg [mabl-1:0] cpu_ad,n_cpu_ad;
  reg [7:0] cpu_wd;
  always @* begin
    n_cpu_ad=sel_cpu_ad[1]?
      (sel_cpu_ad[0]?cpu_ad:u4_pc_in):
      (sel_cpu_ad[0]?cpu_ad+1:init_addr);
    // 00:init_addr 01:cpu_ad+1 10:u4_pc_in 11:cpu_ad
    cpu_wd=sel_di[1]?
      (sel_di[0]?temp[31:24]:temp[23:16]):
      (sel_di[0]?temp[15:8]:temp[7:0]);
  end

  always @(posedge clk) begin
    cpu_state<=n_cpu_state;
    instr_stg<=n_instr_stg;
    r_stg<=n_r_stg;
    cpu_ad<=n_cpu_ad;
    if (instr_we) 
      if (sel_instr==0) instr[7:0]<=u3_rda[7:0];
      else if (sel_instr==1) instr[15:8]<=u3_rda[7:0];
      else if (sel_instr==2) instr[23:16]<=u3_rda[7:0];
      else if (sel_instr==3) instr[31:24]<=u3_rda[7:0];
    if (rmem_rst) rmem<=0;
    else if (rmem_we)
      if (sel_rmem==0) rmem[7:0]<=u3_rda[7:0];
      else if (sel_rmem==1) rmem[15:8]<=u3_rda[7:0];
      else if (sel_rmem==2) rmem[23:16]<=u3_rda[7:0];
      else if (sel_rmem==3) rmem[31:24]<=u3_rda[7:0];
  end

  always @* begin
    n_cpu_state=cpu_state;
    n_instr_stg=instr_stg;
    n_r_stg=r_stg;
    sel_cpu_ad=2'b11;
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
          sel_cpu_ad=0;
        end
        1:case (r_stg)
          0:begin
            n_r_stg=1;
            sel_cpu_ad=1;
          end
          1:begin
            n_r_stg=2;
            sel_cpu_ad=1;
            instr_we=1;
            sel_instr=0;
          end
          2:begin
            n_r_stg=3;
            sel_cpu_ad=1;
            instr_we=1;
            sel_instr=1;
          end
          3:begin
            n_r_stg=4;
            sel_cpu_ad=1;
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
        //2: begin
        //end
        ///*
        2:
        case (instr[6:0])
          7'b1100111:case (instr_stg) //jalr
            0:n_instr_stg=1;
            1:n_instr_stg=2;
            2:begin
              n_instr_stg=0;
              n_cpu_state=1;
              sel_cpu_ad=2;
            end
          endcase
          //
          7'b1100011:case (instr[14:12])
            default:case (instr_stg) //all branch instructions
              0:n_instr_stg=1; //load flags to temp
              1:begin //set new pc accordingly
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ad=2;
              end
            endcase
          endcase
          //
          7'b0000011:case (instr[14:12])
            0:case (instr_stg) //lb
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_cpu_ad=2;
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
                sel_cpu_ad=2;
              end
            endcase
            3'b100:case (instr_stg) //lbu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_cpu_ad=2;
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
                sel_cpu_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //lh
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_cpu_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ad=1;
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
                sel_cpu_ad=2;
              end
            endcase
            3'b101:case (instr_stg) //lhu
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_cpu_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ad=1;
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
                sel_cpu_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //lw
              0:begin // load address to cpu_ad
                rmem_rst=1;
                sel_cpu_ad=2;
                n_instr_stg=1;
              end
              1: n_instr_stg=2; //wait for sample
              2: begin 
                // increment while waiting for sample
                sel_cpu_ad=1;
                n_instr_stg=3;
              end
              3:begin //load first byte and increment again
                rmem_we=1;
                sel_rmem=0;
                n_instr_stg=4;
                sel_cpu_ad=1;
              end
              4:begin //load second byte and increment again
                rmem_we=1;
                sel_rmem=1;
                n_instr_stg=5;
                sel_cpu_ad=1;
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
                sel_cpu_ad=2;
              end
            endcase
          endcase
          7'b0100011:case (instr[14:12])
            0:case (instr_stg) //sb
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_cpu_ad=2;
                n_instr_stg=2;
              end
              2:begin //store
                cpu_we=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ad=2;
              end
            endcase
            3'b001:case (instr_stg) //sh
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_cpu_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte and increment
                cpu_we=1;
                n_instr_stg=3;
                sel_cpu_ad=1;
              end
              3:begin //store second byte
                cpu_we=1;
                sel_di=1;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ad=2;
              end
            endcase
            3'b010:case (instr_stg) //sw
              0: n_instr_stg=1; //load src to temp
              1: begin //load address to cpu_ad
                sel_cpu_ad=2;
                n_instr_stg=2;
              end
              2:begin //store first byte
                cpu_we=1;
                n_instr_stg=3;
                sel_cpu_ad=1;
              end
              3:begin //store second byte
                cpu_we=1;
                sel_di=1;
                n_instr_stg=4;
                sel_cpu_ad=1;
              end
              4:begin //store third byte
                cpu_we=1;
                sel_di=2;
                n_instr_stg=5;
                sel_cpu_ad=1;
              end
              5:begin //store last byte
                cpu_we=1;
                sel_di=3;
                n_instr_stg=0;
                n_cpu_state=1;
                sel_cpu_ad=2;
              end
            endcase
          endcase
          7'b0:begin
            cpu_cede=1;
          end
          default:begin // unspecified instructions are assumed to take 1 cycle
            n_cpu_state=1;
            sel_cpu_ad=2;
          end
        endcase
        //*/
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
      ///*
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
                pc_sel=2'b11; //pass alu to cpu_ad
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
                pc_sel=2'b11; //pass alu to cpu_ad
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
                pc_sel=2'b11; //pass alu to cpu_ad
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
                pc_sel=2'b11; //pass alu to cpu_ad
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
                pc_sel=2'b11; //pass alu to cpu_ad
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
      //*/
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
    reg [1:0] pc_sel;
    reg [2:0] flags_sel,wd_sel;
    reg [31:0] pc_next;
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

    always @* led=~(
    ~btn[1]?(state):
      (dip[1]?
        (dip[0]?instr[31:24]:instr[23:16]):
        (dip[0]?instr[15:8]:instr[7:0]))
    );

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
