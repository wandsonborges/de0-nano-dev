# TCL File Generated by Component Editor 16.1
# Tue Feb 26 16:33:02 BRT 2019
# DO NOT MODIFY


# 
# addVector "addVector" v1.0
#  2019.02.26.16:33:02
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module addVector
# 
set_module_property DESCRIPTION ""
set_module_property NAME addVector
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME addVector
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL addVector_avalon
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file addVector_avalon.vhd VHDL PATH src/addVector/addVector_avalon.vhd TOP_LEVEL_FILE
add_fileset_file readPacketsAvalon.vhd VHDL PATH src/addVector/readPacketsAvalon.vhd


# 
# parameters
# 
add_parameter NBITS_ADDR INTEGER 32
set_parameter_property NBITS_ADDR DEFAULT_VALUE 32
set_parameter_property NBITS_ADDR DISPLAY_NAME NBITS_ADDR
set_parameter_property NBITS_ADDR TYPE INTEGER
set_parameter_property NBITS_ADDR UNITS None
set_parameter_property NBITS_ADDR ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_ADDR HDL_PARAMETER true
add_parameter NBITS_PACKETS INTEGER 32
set_parameter_property NBITS_PACKETS DEFAULT_VALUE 32
set_parameter_property NBITS_PACKETS DISPLAY_NAME NBITS_PACKETS
set_parameter_property NBITS_PACKETS TYPE INTEGER
set_parameter_property NBITS_PACKETS UNITS None
set_parameter_property NBITS_PACKETS ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_PACKETS HDL_PARAMETER true
add_parameter FIFO_SIZE INTEGER 1024 ""
set_parameter_property FIFO_SIZE DEFAULT_VALUE 1024
set_parameter_property FIFO_SIZE DISPLAY_NAME FIFO_SIZE
set_parameter_property FIFO_SIZE TYPE INTEGER
set_parameter_property FIFO_SIZE UNITS None
set_parameter_property FIFO_SIZE ALLOWED_RANGES -2147483648:2147483647
set_parameter_property FIFO_SIZE DESCRIPTION ""
set_parameter_property FIFO_SIZE HDL_PARAMETER true
add_parameter FIFO_SIZE_BITS INTEGER 10
set_parameter_property FIFO_SIZE_BITS DEFAULT_VALUE 10
set_parameter_property FIFO_SIZE_BITS DISPLAY_NAME FIFO_SIZE_BITS
set_parameter_property FIFO_SIZE_BITS TYPE INTEGER
set_parameter_property FIFO_SIZE_BITS UNITS None
set_parameter_property FIFO_SIZE_BITS HDL_PARAMETER true
add_parameter NBITS_DATA INTEGER 32
set_parameter_property NBITS_DATA DEFAULT_VALUE 32
set_parameter_property NBITS_DATA DISPLAY_NAME NBITS_DATA
set_parameter_property NBITS_DATA TYPE INTEGER
set_parameter_property NBITS_DATA UNITS None
set_parameter_property NBITS_DATA ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_DATA HDL_PARAMETER true
add_parameter NBITS_BURST INTEGER 4
set_parameter_property NBITS_BURST DEFAULT_VALUE 4
set_parameter_property NBITS_BURST DISPLAY_NAME NBITS_BURST
set_parameter_property NBITS_BURST TYPE INTEGER
set_parameter_property NBITS_BURST UNITS None
set_parameter_property NBITS_BURST ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_BURST HDL_PARAMETER true
add_parameter NBITS_BYTEEN INTEGER 4
set_parameter_property NBITS_BYTEEN DEFAULT_VALUE 4
set_parameter_property NBITS_BYTEEN DISPLAY_NAME NBITS_BYTEEN
set_parameter_property NBITS_BYTEEN TYPE INTEGER
set_parameter_property NBITS_BYTEEN UNITS None
set_parameter_property NBITS_BYTEEN ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_BYTEEN HDL_PARAMETER true
add_parameter BURST INTEGER 8
set_parameter_property BURST DEFAULT_VALUE 8
set_parameter_property BURST DISPLAY_NAME BURST
set_parameter_property BURST TYPE INTEGER
set_parameter_property BURST UNITS None
set_parameter_property BURST ALLOWED_RANGES -2147483648:2147483647
set_parameter_property BURST HDL_PARAMETER true
add_parameter ADDR_READ1 STD_LOGIC_VECTOR 939524096
set_parameter_property ADDR_READ1 DEFAULT_VALUE 939524096
set_parameter_property ADDR_READ1 DISPLAY_NAME ADDR_READ1
set_parameter_property ADDR_READ1 WIDTH 32
set_parameter_property ADDR_READ1 TYPE STD_LOGIC_VECTOR
set_parameter_property ADDR_READ1 UNITS None
set_parameter_property ADDR_READ1 ALLOWED_RANGES 0:4294967295
set_parameter_property ADDR_READ1 HDL_PARAMETER true
add_parameter ADDR_READ2 STD_LOGIC_VECTOR 940572672
set_parameter_property ADDR_READ2 DEFAULT_VALUE 940572672
set_parameter_property ADDR_READ2 DISPLAY_NAME ADDR_READ2
set_parameter_property ADDR_READ2 WIDTH 32
set_parameter_property ADDR_READ2 TYPE STD_LOGIC_VECTOR
set_parameter_property ADDR_READ2 UNITS None
set_parameter_property ADDR_READ2 ALLOWED_RANGES 0:4294967295
set_parameter_property ADDR_READ2 HDL_PARAMETER true
add_parameter ADDR_WRITE STD_LOGIC_VECTOR 941621248
set_parameter_property ADDR_WRITE DEFAULT_VALUE 941621248
set_parameter_property ADDR_WRITE DISPLAY_NAME ADDR_WRITE
set_parameter_property ADDR_WRITE WIDTH 32
set_parameter_property ADDR_WRITE TYPE STD_LOGIC_VECTOR
set_parameter_property ADDR_WRITE UNITS None
set_parameter_property ADDR_WRITE ALLOWED_RANGES 0:4294967295
set_parameter_property ADDR_WRITE HDL_PARAMETER true


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""

add_interface_port reset_sink rst_n reset_n Input 1


# 
# connection point slave_1
# 
add_interface slave_1 avalon end
set_interface_property slave_1 addressUnits WORDS
set_interface_property slave_1 associatedClock clock
set_interface_property slave_1 associatedReset reset_sink
set_interface_property slave_1 bitsPerSymbol 8
set_interface_property slave_1 burstOnBurstBoundariesOnly false
set_interface_property slave_1 burstcountUnits WORDS
set_interface_property slave_1 explicitAddressSpan 0
set_interface_property slave_1 holdTime 0
set_interface_property slave_1 linewrapBursts false
set_interface_property slave_1 maximumPendingReadTransactions 1
set_interface_property slave_1 maximumPendingWriteTransactions 0
set_interface_property slave_1 readLatency 0
set_interface_property slave_1 readWaitTime 1
set_interface_property slave_1 setupTime 0
set_interface_property slave_1 timingUnits Cycles
set_interface_property slave_1 writeWaitTime 0
set_interface_property slave_1 ENABLED true
set_interface_property slave_1 EXPORT_OF ""
set_interface_property slave_1 PORT_NAME_MAP ""
set_interface_property slave_1 CMSIS_SVD_VARIABLES ""
set_interface_property slave_1 SVD_ADDRESS_GROUP ""

add_interface_port slave_1 slave_chipselect chipselect Input 1
add_interface_port slave_1 slave_read read Input 1
add_interface_port slave_1 slave_write write Input 1
add_interface_port slave_1 slave_address address Input 3
add_interface_port slave_1 slave_writedata writedata Input 32
add_interface_port slave_1 slave_waitrequest waitrequest Output 1
add_interface_port slave_1 slave_readdatavalid readdatavalid Output 1
add_interface_port slave_1 slave_readdata readdata Output 32
add_interface_port slave_1 slave_byteenable byteenable Input nbits_byteen
set_interface_assignment slave_1 embeddedsw.configuration.isFlash 0
set_interface_assignment slave_1 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment slave_1 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment slave_1 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avalon_wr
# 
add_interface avalon_wr avalon start
set_interface_property avalon_wr addressUnits SYMBOLS
set_interface_property avalon_wr associatedClock clock
set_interface_property avalon_wr associatedReset reset_sink
set_interface_property avalon_wr bitsPerSymbol 8
set_interface_property avalon_wr burstOnBurstBoundariesOnly false
set_interface_property avalon_wr burstcountUnits WORDS
set_interface_property avalon_wr doStreamReads false
set_interface_property avalon_wr doStreamWrites false
set_interface_property avalon_wr holdTime 0
set_interface_property avalon_wr linewrapBursts false
set_interface_property avalon_wr maximumPendingReadTransactions 0
set_interface_property avalon_wr maximumPendingWriteTransactions 0
set_interface_property avalon_wr readLatency 0
set_interface_property avalon_wr readWaitTime 1
set_interface_property avalon_wr setupTime 0
set_interface_property avalon_wr timingUnits Cycles
set_interface_property avalon_wr writeWaitTime 0
set_interface_property avalon_wr ENABLED true
set_interface_property avalon_wr EXPORT_OF ""
set_interface_property avalon_wr PORT_NAME_MAP ""
set_interface_property avalon_wr CMSIS_SVD_VARIABLES ""
set_interface_property avalon_wr SVD_ADDRESS_GROUP ""

add_interface_port avalon_wr masterwr_address address Output nbits_addr
add_interface_port avalon_wr masterwr_waitrequest waitrequest Input 1
add_interface_port avalon_wr masterwr_write write Output 1
add_interface_port avalon_wr masterwr_writedata writedata Output nbits_data


# 
# connection point avalon_rd2
# 
add_interface avalon_rd2 avalon start
set_interface_property avalon_rd2 addressUnits SYMBOLS
set_interface_property avalon_rd2 associatedClock clock
set_interface_property avalon_rd2 associatedReset reset_sink
set_interface_property avalon_rd2 bitsPerSymbol 8
set_interface_property avalon_rd2 burstOnBurstBoundariesOnly false
set_interface_property avalon_rd2 burstcountUnits WORDS
set_interface_property avalon_rd2 doStreamReads false
set_interface_property avalon_rd2 doStreamWrites false
set_interface_property avalon_rd2 holdTime 0
set_interface_property avalon_rd2 linewrapBursts false
set_interface_property avalon_rd2 maximumPendingReadTransactions 8
set_interface_property avalon_rd2 maximumPendingWriteTransactions 0
set_interface_property avalon_rd2 readLatency 0
set_interface_property avalon_rd2 readWaitTime 1
set_interface_property avalon_rd2 setupTime 0
set_interface_property avalon_rd2 timingUnits Cycles
set_interface_property avalon_rd2 writeWaitTime 0
set_interface_property avalon_rd2 ENABLED true
set_interface_property avalon_rd2 EXPORT_OF ""
set_interface_property avalon_rd2 PORT_NAME_MAP ""
set_interface_property avalon_rd2 CMSIS_SVD_VARIABLES ""
set_interface_property avalon_rd2 SVD_ADDRESS_GROUP ""

add_interface_port avalon_rd2 masterrd2_address address Output nbits_addr
add_interface_port avalon_rd2 masterrd2_read read Output 1
add_interface_port avalon_rd2 masterrd2_readdata readdata Input nbits_data
add_interface_port avalon_rd2 masterrd2_readdatavalid readdatavalid Input 1
add_interface_port avalon_rd2 masterrd2_waitrequest waitrequest Input 1
add_interface_port avalon_rd2 masterrd2_burstcount burstcount Output 4


# 
# connection point avalon_rd1_1_1_1
# 
add_interface avalon_rd1_1_1_1 avalon start
set_interface_property avalon_rd1_1_1_1 addressUnits SYMBOLS
set_interface_property avalon_rd1_1_1_1 associatedClock clock
set_interface_property avalon_rd1_1_1_1 associatedReset reset_sink
set_interface_property avalon_rd1_1_1_1 bitsPerSymbol 8
set_interface_property avalon_rd1_1_1_1 burstOnBurstBoundariesOnly false
set_interface_property avalon_rd1_1_1_1 burstcountUnits WORDS
set_interface_property avalon_rd1_1_1_1 doStreamReads false
set_interface_property avalon_rd1_1_1_1 doStreamWrites false
set_interface_property avalon_rd1_1_1_1 holdTime 0
set_interface_property avalon_rd1_1_1_1 linewrapBursts false
set_interface_property avalon_rd1_1_1_1 maximumPendingReadTransactions 8
set_interface_property avalon_rd1_1_1_1 maximumPendingWriteTransactions 0
set_interface_property avalon_rd1_1_1_1 readLatency 0
set_interface_property avalon_rd1_1_1_1 readWaitTime 1
set_interface_property avalon_rd1_1_1_1 setupTime 0
set_interface_property avalon_rd1_1_1_1 timingUnits Cycles
set_interface_property avalon_rd1_1_1_1 writeWaitTime 0
set_interface_property avalon_rd1_1_1_1 ENABLED true
set_interface_property avalon_rd1_1_1_1 EXPORT_OF ""
set_interface_property avalon_rd1_1_1_1 PORT_NAME_MAP ""
set_interface_property avalon_rd1_1_1_1 CMSIS_SVD_VARIABLES ""
set_interface_property avalon_rd1_1_1_1 SVD_ADDRESS_GROUP ""

add_interface_port avalon_rd1_1_1_1 masterrd1_address address Output nbits_addr
add_interface_port avalon_rd1_1_1_1 masterrd1_read read Output 1
add_interface_port avalon_rd1_1_1_1 masterrd1_readdata readdata Input nbits_data
add_interface_port avalon_rd1_1_1_1 masterrd1_readdatavalid readdatavalid Input 1
add_interface_port avalon_rd1_1_1_1 masterrd1_waitrequest waitrequest Input 1
add_interface_port avalon_rd1_1_1_1 masterrd1_burstcount burstcount Output 4

