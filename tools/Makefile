bin/loader: src/loader.c
	cc -O3 src/loader.c -lftdi -lpthread -o bin/loader
bin/prog.out: src/prog.S
	#riscv32-elf-as src/prog.S -o bin/prog.out
	riscv32-elf-as src/prog.S -o bin/prog.out
bin/fsend: src/fsend.c
	cc -O3 src/fsend.c -lftdi -o bin/fsend
bin/receive: src/receive.c
	cc -O3 src/receive.c -lftdi -lpthread -o bin/receive
bin/send: src/send.c
	cc -O3 src/send.c -lftdi -lpthread -o bin/send

.PHONY: send see hex nx
send: bin/prog.out bin/loader
	bin/loader bin/prog.out
nx: bin/prog.out a.out
	bin/loader bin/prog.out nx
see: bin/prog.out
	riscv32-elf-objdump -d bin/prog.out
hex: bin/prog.out
	hexdump bin/prog.out
	
