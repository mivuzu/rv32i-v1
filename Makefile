.PHONY: synth one_pass layout bitstream load flash check_usage
DEP_SRC=src/*.v lib/hdl/alu.v lib/hdl/uart.v lib/hdl/pll.v
#DEP_NETLISTS=obj/memory.v obj/memmgr.v obj/core.v
#obj/memory.v: src/memory.v
#	yosys -qp "synth_ecp5 -top memory; select -module memory; write_verilog -noattr -noexpr -nodec $@" $^
#	
#obj/memmgr.v: src/memmgr.v
#	yosys -qp "synth_ecp5 -top memmgr; select -module memmgr; write_verilog -noattr -noexpr -nodec $@" $^
#	
#obj/fsm.v: src/fsm.v
#	yosys -qp "synth_ecp5 -top fsm; select -module fsm; write_verilog -noattr -noexpr -nodec $@" $^
#obj/mem_controller.v: src/mem_controller.v
#	yosys -qp "synth_ecp5 -top mem_controller; select -module mem_controller; write_verilog -noattr -noexpr -nodec $@" $^
#obj/datapath_control.v: src/datapath_control.v
#	yosys -qp "synth_ecp5 -top datapath_control; select -module datapath_control; write_verilog -noattr -noexpr -nodec $@" $^
#obj/datapath.v: src/datapath.v src/datapath_control.v src/regfile.v ../lib/hdl/alu.v
#	yosys -qp "synth_ecp5 -top datapath; select -module datapath; write_verilog -noattr -noexpr -nodec $@" $^
#	
#	
#obj/core.v: src/core.v obj/fsm.v obj/datapath_control.v obj/datapath.v obj/mem_controller.v
#	yosys -qp "\
#		synth_ecp5 -top core; \
#		select -module core; \
#		write_verilog -noattr -noexpr -nodec $@" $^
#
#obj/hardware.json: $(DEP_NETLISTS) src/main.v ../lib/hdl/*
#	yosys -qp \
#		 "synth_ecp5 -top main -abc9; write_json obj/hardware.json" \
#		 $^
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
	cat obj/npr_report.json | jq . | grep TRELLIS_COMB -A 3
