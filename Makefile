PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
RTL := rtl/rv32i_core.v rtl/rv32i_soc.v

.PHONY: all program program-edge reference reference-edge check-python sim sim-edge sim-decode test synth equiv netlist verify clean
all: test

program:
	$(PYTHON) tools/build_program.py

program-edge:
	$(PYTHON) tools/build_edge_program.py

reference: program
	$(PYTHON) tools/reference_model.py

reference-edge: program-edge
	$(PYTHON) tools/edge_reference.py

check-python: reference reference-edge
	$(PYTHON) -m compileall -q tools

sim: program
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -I tb -s tb_soc -o build/rv32i_sim $(RTL) tb/tb_soc.v
	$(VVP) build/rv32i_sim

sim-edge: reference-edge
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -I tb -s tb_soc_edge -o build/rv32i_edge_sim $(RTL) tb/tb_soc_edge.v
	$(VVP) build/rv32i_edge_sim

sim-decode:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -I tb -s tb_core_decode -o build/rv32i_decode_sim rtl/rv32i_core.v tb/tb_core_decode.v
	$(VVP) build/rv32i_decode_sim

test:
	$(PYTHON) tools/run_flow.py test

synth:
	$(PYTHON) tools/run_flow.py synth

equiv:
	$(PYTHON) tools/run_flow.py equiv

netlist:
	$(PYTHON) tools/run_flow.py netlist

verify:
	$(PYTHON) tools/run_flow.py all

clean:
	rm -rf build
