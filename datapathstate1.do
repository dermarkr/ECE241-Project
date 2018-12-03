# set the working dir, where all compiled verilog goes
vlib work

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files
vlog main.v

#load simulation using mux as the top level simulation module
vsim datapath

#log all signals and add some signals to waveform window
log {/*}
# add wave {/*} would add all items in top level simulation module
add wave {/*}

force {clk} 0 0ns, 1 {5ns} -r 10ns

force {prestart} 0
run 10 ns

force {prestart} 1
run 10 ns

force {prestart} 0
run 10 ns

force {win} 1
run 60 ns

force {win} 0
run 30 ns

force {win} 0
run 10 ns

force {win} 0
run 10 ns

force {win} 1
run 10 ns