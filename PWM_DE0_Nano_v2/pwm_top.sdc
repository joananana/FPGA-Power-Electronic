# Clock principal da DE0-Nano
# Frequencia: 50 MHz
# Periodo: 20 ns

create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

derive_clock_uncertainty