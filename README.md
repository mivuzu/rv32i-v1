# rv32i-v1
First version of my personal design of a RISC-V 32-bit core.

It supports only the base integer instruction set (minus the memory ordering and environment instructions, that is: `fence, fence.tso, pause, ecall` and `ebreak`), hence the repository name.
It's built for the ECP5 using the yosys+nextpnr toolchain, and while I've worked on it with ECP5 Evaluation board from Lattice, it should work on basically any ECP5 with only minor tweaks, like setting the correct UART ports and changing the memory size to suit the target model.

As it stands built for my particular model, it has a 425KB memory, from the on chip memory banks. 
I've also added an MMIO UART interface for the CPU, and of course the code for the CPU is loaded onto memory via UART.

## Basic Functionality
At first the design will start in memory initialization mode, in this mode memory writes and reads can be done from a PC via UART. 5-byte commands may be issued to specify the desired operation (or only single byte commands if the operation is not memory related). The general form of a command is the following:

\[Transfer Size (`size`) - 19 bits]|\[Base Address (`base`) - 19 bits\]|\[Operation - 2 bits\]

As you would expect there are only 4 posible operations;

`00`: Memory read of `size` bytes starting at address `base`<br/>
`01`: Memory write of `size` bytes starting at address `base`<br/>
`10`: Read value of CPU register `{command[3],command[7:4]}`<br/>
`11`: Start CPU execution

For memory reads the FPGA will simply transfer requested memory section, from lowest to highest byte.<br/>
As for writes, the FPGA will expect an additional `size` bytes to complete the operation, writing each one to memory starting at address `base`

If `op` is either `10` or  `11`, only a single byte will issue the particular operation.<br/>
With CPU register reads (`op=='b10`), 4 bytes will be sent, the contents of the specified register.<br/>
Operation `10` is rather self explanatory. 

Upon starting execution the FPGA will switch to CPU mode, and any further commands will be ignored, instead any data sent over UART while the CPU is executing will be stored in memory for the CPU to access, and note that the CPU may also send data of its own (see UART interface bellow)

If the CPU reaches a `0` instruction (first 7 bits are 0, most likely unwritten memory), the FPGA will switch back to memory initialization mode.
