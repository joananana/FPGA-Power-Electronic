# Executar no Questa a partir desta pasta: do run_modelsim.do
if {![file isdirectory work]} {vlib work}
vcom -93 pwm_core.vhd
vcom -93 tb_pwm_core.vhd
vsim work.tb_pwm_core
add wave -r sim:/tb_pwm_core/*
run -all
wave zoom full
