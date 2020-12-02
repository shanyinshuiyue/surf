# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/fixed"
loadSource -lib surf -dir "$::DIR_PATH/logic"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb/fixed"

# Fixed and floating-point package support in VHDL-2008
if { $::env(VIVADO_VERSION) >= 2020.2 } {
   loadSource -lib surf           -dir "$::DIR_PATH/float"    -fileType "VHDL 2008"
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb/float" -fileType "VHDL 2008"
} else {
   puts "\n\nWARNING: $::DIR_PATH/float requires Vivado 2020.2 (or later)\n\n"
}
