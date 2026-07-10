## =============================================================
## XDC Constraints - ZCU104 (xczu7ev-ffvc1156-2-e)
## Target: top_module
## Verified against UG1267 v1.1 (ZCU104 Evaluation Board User Guide)
## =============================================================
## ---------------------------------------------------------------
## Clock (125 MHz, IDT8T49N287 clock generator output CLK_125,
## differential LVDS pair, Table 3-13 of UG1267)
## ---------------------------------------------------------------
set_property PACKAGE_PIN H11 [get_ports i_clk_p]
set_property PACKAGE_PIN G11 [get_ports i_clk_n]
set_property IOSTANDARD LVDS [get_ports i_clk_p]
set_property IOSTANDARD LVDS [get_ports i_clk_n]
create_clock -period 8.000 -name sys_clk -waveform {0.000 4.000} [get_ports i_clk_p]
## top_module now takes i_clk_p/i_clk_n directly (buffered internally via
## IBUFDS) to match this LVDS-only clock source.
## ---------------------------------------------------------------
## Reset push button (CPU_RESET, SW20 - dedicated reset pushbutton,
## Bank 87, VCC3V3, Table 2-1/UG1267 callout 19)
## ---------------------------------------------------------------
set_property PACKAGE_PIN M11 [get_ports i_btnC]
set_property IOSTANDARD LVCMOS33 [get_ports i_btnC]
## i_btnC is asynchronous w.r.t. w_fsm_clk in this design (w_safe_reset is
## used directly inside an always @(posedge w_fsm_clk) block), so this
## path is excluded from timing analysis.
set_false_path -from [get_ports i_btnC]
## ---------------------------------------------------------------
## LEDs (DS37-DS40, Bank 88, VCC3V3 - Table 2-1/3-2 of UG1267)
## ---------------------------------------------------------------
set_property PACKAGE_PIN D5 [get_ports {o_led[0]}]
set_property PACKAGE_PIN D6 [get_ports {o_led[1]}]
set_property PACKAGE_PIN A5 [get_ports {o_led[2]}]
set_property PACKAGE_PIN B5 [get_ports {o_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[3]}]
