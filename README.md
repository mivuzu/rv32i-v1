# rv32i-v1

Minimal RISC-V 32-bit soft CPU for Lattice ECP5, first iteration. Only supports the base integer ISA, hence the repository name. Memory-ordering and environment instructions `fence`, `fence.tso`, `pause`, `ecall`, `ebreak` are effetively treated as a `nop`, as are all unknown intructions with the expection of zero instructions, more on that later.

As for the microachitecture it's a simple multycyle design running on a single 8-bit memory bus, drawing heavily from the design on Sarah Harris' Digital Design and Computer Architecture. I have not extensively tested it, however all I've run on it works as expected. This is simply a personal project and it shouldn't be used for any serious use case, but I encourage you to test it.

## Basic Operation

At power up the FPGA enters memory-initialization mode in which a PC can read/write memory over UART. CPU execution is also issued via UART in this mode. While executing the CPU will ignore UART commands and will instead buffer received data to a particular section in memory. Zero instructions (first 7 bits zero) will stop CPU execution and make the system return to memory-init mode.``

### Host Command Format

General bit layout of a command:

    [ Transfer Size (size) – 19 bits ] | [ Base Address (base) – 19 bits ] | [ Operation (op) – 2 bits ]

5 byte commands, possibly 1 byte if `op` is `10` or `11`.

Operations:

| op  | Meaning                                                      |
|-----|--------------------------------------------------------------|
| 00  | Memory read of `size` bytes starting at `base`               |
| 01  | Memory write of `size` bytes starting at `base`              |
| 10  | Read CPU register `{command[3], command[7:4]}` (sends 4 bytes) |
| 11  | Start CPU execution                                          |

Naturally, for writes the host must send `size` additional bytes to complete the command, which will be the written data.
As mentioned before commands are ignored during CPU execution, incoming UART data will instead be buffered to memory.

## MMIO UART

The CPU UART interface occupies the last 4 KiB of RAM (wired to the last two DP16KDs used by the memory module) to simplify porting when total memory changes.

| Address Range     | Function                                                                                 |
|-------------------|------------------------------------------------------------------------------------------|
| `0x67000`           | TX flags. Set bit0=1 to start a transfer. During transfer it's set to 0x8e and after completion to 0 |
| `0x67001–0x67002`   | Transfer size (16-bit unsigned, LSB at 0x67001, values greater than 2045 are ignored)    |
| `0x67003–0x677FF`   | 2045-byte TX buffer (data to send)                                                       |
| `0x67800`           | RX flag (set to 1 when data is received)                                                 |
| `0x67801–0x67802`   | RX count (16-bit unsigned, increments per received byte, resets after 2045)            |
| `0x67803–0x67FFF`   | 2045-byte RX buffer (after 2045 previously stored data is overwriten)     |

- RX bytes are ordered as received, i.e `0x67803` holds the first byte. TX bytes are also transferred starting at `0x67003`.
- The CPU may overwrite RX count, which results in the controller now writing data to the corresponding offset.
- 115200 baud, 8N1. See `lib/hdl/uart.v` to change baud rate.

## Build & Run

Commands here are from the Makefile. If you run them as is, without changing the Makefile or project at all, a bitstream for the ECP5 EVN 
will be generated and loaded.

1) Install yosys, nextpnr-ecp5, ecppack and openFPGALoader (or whatever tools your toolchain requires and modify the Makefile).
2) Configure board constraints (UART pins, clock, etc. on `lib/pins.lpf`).
3) Synthesize, place & route, pack:

       make bitstream

4) Connect a serial terminal at 115200 8N1 and load/flash

       make load # or make flash

5) Use the host UART protocol to load your program into RAM, then issue op=11 (start).

## Porting
If you try to run this on another board there are three main things you should change:

- Memory size; set the `memblks` parameter in `memory.v` to the amount of DP16KD blocks of your particular model.
- Pin constraints; change `lib/pins.lpf` to match the pin layout of your board. The only critical pins for the design are the UART pins and the clock. In the design the input clock is assumed to be 12MHz and then multiplied to 100MHz so bear that in mind.
- Makefile, as some commands are particular to the ECP5 EVN.

## Work for the future

- v2: pipelined core, wider/faster memory module
- v3: ISA expansion to RV32GC
- v4: 64-bit (RV64GC)

