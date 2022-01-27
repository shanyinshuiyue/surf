# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl" -fileType "VHDL 2008"
loadSource -lib surf -dir "$::DIR_PATH/ip_integrator"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
