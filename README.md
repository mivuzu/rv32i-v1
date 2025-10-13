# rv32i-v1
First version of my personal design of a RISC-V 32-bit core.

It supports only the base integer instruction set (minus the memory ordering and environment instructions, that is: `fence, fence.tso, pause, ecall` and `ebreak`), hence the repository name.
It's built for the ECP5 using the yosys+nextpnr toolchain, and while I've worked on it with ECP5 Evaluation board from Lattice, it should work on basically any ECP5 with only minor tweaks, like setting the correct UART ports and changing the memory size to suit the target model.

The CPU itself has a simple multicyle microarchitecture, no pipelining, nothing fancy. This is why I've put V1 on the name, I intend to make a pipelined design on version 2, as well as making the memory module wider and faster as to speed things up.

As it stands built for my particular model, it has a 425KB memory, from the on chip memory banks. 
I've also added an MMIO UART interface for the CPU, and of course the code for the CPU is loaded onto memory via UART.

I've not tested it extensively, however the tests I've done run as expected and I tested each instruction thoroughly as I wrote it. Still use at your own risk and please do tell me if you find any bugs.

## Basic Functionality
At first the FPGA will start in memory initialization mode, in this mode memory writes and reads can be done from a PC via UART. 5-byte commands may be issued to specify the desired operation (or only single byte commands if the operation is not memory related). The general form of a command is the following:

\[Transfer Size (`size`) - 19 bits]|\[Base Address (`base`) - 19 bits\]|\[Operation (`op`) - 2 bits\]

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

Upon starting execution the FPGA will switch to CPU mode, executing instructions starting at address `0`, and any further commands will be ignored. Instead any data sent over UART while the CPU is executing will be stored in memory for the CPU to access, and note that the CPU may also send data of its own (see UART interface bellow). 

If the CPU reaches a `0` instruction (first 7 bits are 0, most likely unwritten memory), the FPGA will switch back to memory initialization mode.

## UART Interface
As I mentioned there's an MMIO interface for the CPU to access the UART modules, it's mapped this way:

`0x67000`: Start transfer flags, if first bit is set to one a transfer will start.<br/>
`0x67001-0x67002`: Tranfer size, 16 bit unsigned integer, starting at 0x67001.<br/>
`0x67003-0x677ff`: Data to transfer.

Upon finishing a transfer, `0x67000` will be set to `0x80`

`0x67800`: Received flag, will be set to 1 upon receiving data.<br/>
`0x67801-0x67802`: 16-bit received counter, will be incremented upon receiving data, possible overflow after 2045.<br/>
`0x67803-0x67fff`: Received data. Again, may overflow (overwrite).

Data is stored in the order it was received, i.e `0x67803` would be the first byte received.
The CPU may overwrite the received counter, for example if it doesn't care about the stored data it may write 0 to it and received data will start to be overwritten.

The UART interface is 115200 baud, the code for it is not present on this codebase, if you notice the directory specified for it in the Makefile is a link.<br/> I don't think it's relevant for this project, however the final bitstream in the `obj/` directory does contain it. I may commit the module in the future :p along with the ALU and PLL.
