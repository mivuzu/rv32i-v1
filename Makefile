.PHONY: synth one_pass layout bitstream load flash check_usage test test_edit
DEP_SRC=src/*.v lib/hdl/alu.v lib/hdl/uart.v lib/hdl/pll.v

obj/hardware.json: $(DEP_SRC)
	yosys -qp "synth_ecp5 -top main -abc9; write_json obj/hardware.json" $(DEP_SRC)
synth: obj/hardware.json
	
obj/hardware.config: obj/hardware.json lib/pins.lpf
	nextpnr-ecp5 --um5g-85k --speed 8 --package CABGA381 --json obj/hardware.json --textcfg obj/hardware.config --lpf lib/pins.lpf --report obj/npr_report.json -q --threads $$(nproc)
layout: obj/hardware.config
	
obj/hardware.bit: obj/hardware.config
	ecppack --compress --db /opt/oss-cad-suite/share/trellis/database obj/hardware.config obj/hardware.bit
bitstream: obj/hardware.bit
	
load: obj/hardware.bit
	openFPGALoader -b ecp5_evn obj/hardware.bit
flash: obj/hardware.bit
	openFPGALoader -b ecp5_evn obj/hardware.bit -f
check_usage:
	cat obj/npr_report.json | jq .utilization.TRELLIS_COMB
test:
	make load && \
	cd tools/ && \
	make see && \
	make send && \
	#sleep .1 && \
	#bin/send 12 && bin/receive 0 && \
	#bin/send 22 && bin/receive 0 && \
	#bin/send 32 && bin/receive 0 && \
	#bin/memcmd 254 6 0 && bin/receive 0 && \
	cd ..
test_edit:
	hx tools/src/prog.S && make test
