onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_burst_write_wf/clk
add wave -noupdate /tb_burst_write_wf/reset
add wave -noupdate /tb_burst_write_wf/ctrl_busy
add wave -noupdate -radix hexadecimal /tb_burst_write_wf/master_address
add wave -noupdate -radix unsigned -childformat {{{/tb_burst_write_wf/master_burstcount[3]} -radix unsigned} {{/tb_burst_write_wf/master_burstcount[2]} -radix unsigned} {{/tb_burst_write_wf/master_burstcount[1]} -radix unsigned} {{/tb_burst_write_wf/master_burstcount[0]} -radix unsigned}} -expand -subitemconfig {{/tb_burst_write_wf/master_burstcount[3]} {-height 16 -radix unsigned} {/tb_burst_write_wf/master_burstcount[2]} {-height 16 -radix unsigned} {/tb_burst_write_wf/master_burstcount[1]} {-height 16 -radix unsigned} {/tb_burst_write_wf/master_burstcount[0]} {-height 16 -radix unsigned}} /tb_burst_write_wf/master_burstcount
add wave -noupdate /tb_burst_write_wf/master_byteenable
add wave -noupdate /tb_burst_write_wf/master_write
add wave -noupdate -radix hexadecimal /tb_burst_write_wf/master_writedata
add wave -noupdate /tb_burst_write_wf/ctrl_start
add wave -noupdate -radix hexadecimal /tb_burst_write_wf/ctrl_baseaddress
add wave -noupdate /tb_burst_write_wf/ctrl_burstcount
add wave -noupdate /tb_burst_write_wf/master_waitrequest
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {90 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 271
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
WaveRestoreZoom {0 ps} {228 ps}
