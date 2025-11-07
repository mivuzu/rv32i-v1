# rv32i-v1

Minimal RISC-V 32-bit soft CPU for Lattice ECP5, first iteration. Only supports the base integer ISA, hence the repository name (I also didn't include memory-ordering and environment instructions: `fence`, `fence.tso`, `pause`, `ecall`, `ebreak`).

I have not extensively tested it, however I tested it instruction by instruction as I wrote it and I've also run small programs, all works as expected. Still, expect errors if you try it.

## Roadmap

- v1 (current version): RV32I, multicycle, MMIO UART, host-side memory init
- v2: pipelined core, wider/faster memory module
- v3: ISA expansion to RV32GC
- v4: 64-bit (RV64GC)

## Summary

- Target: Lattice ECP5
- Toolchain: yosys+nextpnr
- Microarchitecture: simple multicycle, no pipeline.
- Memory: 416 KiB on-chip RAM (208 2048-byte memory banks; ECP5 “DP16KD” blocks)
- I/O: MMIO UART (115200 baud)
- Host link: UART driven memory init+control protocol

Developed on the ECP5 Evaluation Board. With minor changes, particularly pin constraints and memory size, it should run on most ECP5 boards.

## Basic Operation

At power up the FPGA enters memory-initialization mode:

- A PC can read/write memory and control the CPU over UART using compact commands.
- Starting execution switches the system into CPU mode.
- Encountering an all-zero instruction (first 7 bits zero, likely unwritten memory) returns to memory-init mode.

### Host Command Format

Works over UART.<br/>
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

Note that

- For reads the data is sent from low to high address.
- For writes the host must send `size` additional bytes to complete the command, which will be written from `base` upward.
- During CPU mode, commands are ignored and incoming UART bytes are instead buffered to memory for the CPU.

## MMIO UART

The UART interface occupies the last 4 KiB of RAM (wired to the last two DP16KDs used by the memory module) to simplify porting when total memory changes.

| Address Range     | Function                                                                                 |
|-------------------|------------------------------------------------------------------------------------------|
| `0x67000`           | Start/Status flags. Set bit0=1 to start a transfer. After completion, it is set to `0x80`|
| `0x67001–0x67002`   | Transfer size (16-bit unsigned, LSB at 0x67001, values greater than 2045 are ignored)    |
| `0x67003–0x677FF`   | 2045-byte TX buffer (data to send)                                                       |
| `0x67800`           | RX flag (set to 1 when data is received)                                                 |
| `0x67801–0x67802`   | RX count (16-bit unsigned, increments per received byte, resets after 2045)            |
| `0x67803–0x67FFF`   | 2045-byte RX buffer (after 2045 previously stored data is overwriten)     |

- RX bytes are ordered as received, i.e `0x67803` holds the first byte. TX bytes are also transferred from lowest to highest.
- The CPU may overwrite the RX count, for example, write `0` so new data overwrites old.
- Baud: 115200, see `lib/hdl/uart.v` to change baud rate.

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
- Pin constraints; change `lib/pins.lpf` to match the pin layout of your board. The only critical pins for the design are the UART pins and the clock, in the design the input clock is assumed to be 12MHz and then multiplied to 50MHz so bear that in mind. Delete the `clk12_to_50` module to get rid of the PLL and use the input clock as is if you wish.
- Makefile, since it's tailored for the ECP5 EVN
