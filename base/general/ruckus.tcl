# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
if {  $::env(VIVADO_VERSION) > 0.0} {
   loadSource -lib surf -dir "$::DIR_PATH/ip_integrator"
}

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
