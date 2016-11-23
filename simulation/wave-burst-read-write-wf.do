onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_burst_read_write_wf/ctrl_busy
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/ctrl_readdata
add wave -noupdate /tb_burst_read_write_wf/ctrl_readdatavalid
add wave -noupdate /tb_burst_read_write_wf/ctrl_start
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/master_address
add wave -noupdate -radix unsigned /tb_burst_read_write_wf/master_burstcount
add wave -noupdate /tb_burst_read_write_wf/master_read
add wave -noupdate /tb_burst_read_write_wf/master_readdatavalid
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/master_readdata
add wave -noupdate /tb_burst_read_write_wf/ctrl_writebusy
add wave -noupdate /tb_burst_read_write_wf/ctrl_write
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/ctrl_writedata
add wave -noupdate /tb_burst_read_write_wf/ctrl_writestart
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/master_writeaddress
add wave -noupdate -radix unsigned /tb_burst_read_write_wf/master_writeburstcount
add wave -noupdate /tb_burst_read_write_wf/master_byteenable
add wave -noupdate /tb_burst_read_write_wf/master_write
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/master_writedata
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/ctrl_baseaddress
add wave -noupdate -radix unsigned /tb_burst_read_write_wf/dut_write/burstCount
add wave -noupdate /tb_burst_read_write_wf/ctrl_burstcount
add wave -noupdate /tb_burst_read_write_wf/clk
add wave -noupdate /tb_burst_read_write_wf/reset
add wave -noupdate /tb_burst_read_write_wf/master_waitrequest
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/ctrl_writebaseaddress
add wave -noupdate /tb_burst_read_write_wf/ctrl_writeburstcount
add wave -noupdate /tb_burst_read_write_wf/master_writewaitrequest
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/dut/burstReadBuffer/address
add wave -noupdate /tb_burst_read_write_wf/dut/burstReadBuffer/clock
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/dut/burstReadBuffer/data
add wave -noupdate /tb_burst_read_write_wf/dut/burstReadBuffer/wren
add wave -noupdate -radix hexadecimal /tb_burst_read_write_wf/dut/burstReadBuffer/q
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {330 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 360
configure wave -valuecolwidth 145
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
WaveRestoreZoom {142 ps} {518 ps}
