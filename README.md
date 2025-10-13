# rv32i-v1

Personal design of a minimal RISC-V 32-bit soft CPU for Lattice ECP5, first iteration, written to be easy to port and build upon. It currently implements the base integer ISA only, hence the name (excluding memory-ordering and environment instructions: `fence`, `fence.tso`, `pause`, `ecall`, `ebreak`).

Tested instruction by instruction during implementation, as well as with small programs, however not yet extensively tested. Use at your own risk and please do report issues.

## Roadmap

- v1 (this): RV32I, multicycle, MMIO UART, host-side memory init
- v2: pipelined core, wider/faster memory module
- v3: ISA expansion to RV32GC
- v4: 64-bit (RV64GC)

## Highlights

- Target: Lattice ECP5
- Toolchain: yosys+nextpnr
- Microarchitecture: simple multicycle, no pipeline.
- Memory: 416 KiB on-chip RAM (208 × 2048-byte banks; ECP5 “DP16KD” blocks)
- I/O: MMIO UART (115200 baud)
- Host link: UART driven memory init+control protocol

Developed on the ECP5 Evaluation Board. With minor changes, particularly pin constraints and memory size, it should run on most ECP5 boards.

## Basic Operation

At power-up the FPGA enters memory-initialization mode:

- A PC can read/write memory and control the CPU over UART using compact commands.
- Starting execution switches the system into CPU mode.
- Encountering an all-zero instruction (first 7 bits zero, likely unwritten memory) returns to memory-init mode.

### Host Command Format

Works over UART.<br/>
General bit layout of a command:

    [ Transfer Size (size) – 19 bits ] | [ Base Address (base) – 19 bits ] | [ Operation (op) – 2 bits ]

5 byte commands, possibly 1 byte if `size` and `base` are not used by the particular operation.

Operations:

| op  | Meaning                                                      |
|-----|--------------------------------------------------------------|
| 00  | Memory read of `size` bytes starting at `base`               |
| 01  | Memory write of `size` bytes starting at `base`              |
| 10  | Read CPU register `{command[3], command[7:4]}` (sends 4 bytes) |
| 11  | Start CPU execution                                          |

Notes:

- Reads: FPGA streams bytes from low to high address.
- Writes: host must send `size` additional bytes, written from `base` upward.
- For `10` / `11`, a single byte suffices to issue the operation.
- During CPU mode, commands are ignored and incoming UART bytes are buffered to memory for the CPU.

## MMIO UART

The UART interface occupies the last 4 KiB of RAM (wired to the last two DP16KDs used by the memory module) to simplify porting when total memory changes.

| Address Range     | Function                                                                                 |
|-------------------|------------------------------------------------------------------------------------------|
| 0x67000           | Start/Status flags. Set bit0=1 to start a transfer. After completion, it is set to `0x80`|
| 0x67001–0x67002   | Transfer size (16-bit unsigned, LSB at 0x67001, values greater than 2045 are ignored)    |
| 0x67003–0x677FF   | 2045-byte TX buffer (data to send)                                                       |
| 0x67800           | RX flag (set to 1 when data is received)                                                 |
| 0x67801–0x67802   | RX count (16-bit unsigned, increments per received byte, overflow after 2045)            |
| 0x67803–0x67FFF   | 2045-byte RX buffer (received data, may wrap/overwrite)                                  |

- RX bytes are ordered as received, i.e `0x67803` holds the first byte, and so are TX bytes.
- The CPU may overwrite the RX count, e.g., write `0` so new data overwrites old.
- Baud: 115200, see `lib/hdl/uart.v` to change baud rate.

## Porting Notes

- UART and clock pins: update constraints for your board on `lib/pins.lpf`
- Memory size: set the number of DP16KD banks in `memory.v`.

## Build & Run

Commands here are indicative, adapt to your board toolchain. If you run them as is, without changing the Makefile or project at all, a bitstream for the ECP5 Ev. Board 
will be generated and loaded.

1) Install yosys, nextpnr-ecp5, ecppack and openFPGALoader (or whatever tools your toolchain requires and modify Makefile).
2) Configure board constraints (UART pins, clock, etc. on `lib/pins.lpf`).
3) Synthesize, place & route, pack:

       make bitstream

4) Connect a serial terminal at 115200 8N1 and load/flash

       make load # or make flash

5) Use the host UART protocol to load your program into RAM, then issue op=11 (start).

## Repository Structure
    src/            # core, memory, mmio
    obj/            # build artifacts
    lib/            # pin constraints and hdl I reuse often (UART, ALU and PLL).
    tools/          # host-side UART loader/scripts (not yet uploaded)

## Design Overview

- Core: RV32I multicycle controller + ALU + regfile + memory load/store
- Memory subsystem: parameterized DP16KD bank array (208 × 2 KiB ≈ 416 KiB ≈ ~425 KB decimal)
- MMIO: UART mapped into the highest 4 KiB of address space
- Boot flow: UART memory-init, send a command with `op=11` to start at PC=0
- Utilization is roughly 7k luts. See `obj/npr_report.json` for further utilization info.

## Known Limitations

- No `fence/*`, `ecall`, `ebreak`, `pause`
- No pipeline, performance is intentionally modest

## Future Work

- v2: 5 stage pipeline, hazard handling, wider memory datapath + burst transfers for throughput
- v3: RV32GC
- v4: RV64GC

## Contributing

Issues and PRs are welcome, especially board port contributions, verification tests, program runs, and stress testing
