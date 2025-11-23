li x31, 4096 # rx buffer
li x30, 2048 # tx buffer
li x29,10
li x28,1
li x27, 0x8e

rcheck:
lbu x1, 0(x31)
beq x0,x1,rcheck
sb x0, 0(x31)
sh x0, 1(x31)
lbu x2, 3(x31)
sb x2, 3(x30)
sh x28, 1(x30)
sb x28, 0(x30)
await:
lbu x3, 0(x30)
bne x0,x3,await
j rcheck

#addi x7,x29,0
#j store
#dec:
#addi x7,x7,-1
#store:
#addi x8,x7,2
#add x8,x8,x30
#sb x7,0(x8)
#bne x27,x7,dec
#
#send:
#sh x29,1(x30)
#sb x28,0(x30)
#
#li x6,0x80
#check:
#lbu x5,0(x30)
#bne x5,x6,check

end:
