onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_burst_read_wf/clk
add wave -noupdate /tb_burst_read_wf/reset
add wave -noupdate /tb_burst_read_wf/ctrl_busy
add wave -noupdate -radix hexadecimal /tb_burst_read_wf/master_address
add wave -noupdate -radix unsigned /tb_burst_read_wf/master_burstcount
add wave -noupdate /tb_burst_read_wf/master_read
add wave -noupdate /tb_burst_read_wf/master_waitrequest
add wave -noupdate /tb_burst_read_wf/master_readdatavalid
add wave -noupdate -radix hexadecimal /tb_burst_read_wf/master_readdata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {239 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 315
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {79461 ps} {80029 ps}
