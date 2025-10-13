.option norelax
_start:
        #li x31,0x800
        #lui x30,0x00067
        #or x31,x31,x30
        #li x1,0xaa
        #sb x1, 0(x31)

        #li x31,0x800
        #lui x30,0x00067
        #or x31,x31,x30
        #li x2,3
        #sh x2, 1(x31)
#rx_wait:
        #lb x1, 0(x31)
        #beq x1,x0,rx_wait
        #addi x1,x0,0
        #sb x1, 0(x31)
        ##lh x1, 1(x31)
        ##addi x2,x0,3
        ##bne x1,x2,_start

        lui x31,0x00067
        li x1,0xaa
        sb x1, 3(x31)
        li x1,0xff
        sb x1, 4(x31)
        li x1,0x15
        sb x1, 5(x31)
        li x1,0x26
        sb x1, 6(x31)
        #
        li x2,0x80
        li x1, 5
        sh x1, 1(x31)
        li x1,1
        sb x1, 0(x31)
wait:
        lbu x1, 0(x31)
        and x1,x1,x2
        beq x1,x0,wait
        sb x0, 0(x31)
        
        

        #addi x1,x0,2
        #sw x1, 3(x31)
        #addi x1,x0,0xaa
        #sb x1, 4(x31)
        #addi x1,x0,0x55
        #sb x1, 5(x31)
        #addi x1,x0,1
        #sb x1, 0(x31)

        #addi x1,x0,3
        #sb x1, 0(x0)
        

