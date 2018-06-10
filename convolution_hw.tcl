# TCL File Generated by Component Editor 16.1
# Tue May 22 16:09:23 BRT 2018
# DO NOT MODIFY


# 
# convolution "convolution" v1.0
#  2018.05.22.16:09:23
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module convolution
# 
set_module_property DESCRIPTION ""
set_module_property NAME convolution
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME convolution
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL conv_avalon
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file conv_avalon.vhd VHDL PATH src/conv/conv_avalon.vhd TOP_LEVEL_FILE
add_fileset_file conv_core.vhd VHDL PATH src/conv/conv_core.vhd
add_fileset_file conv_package.vhd VHDL PATH src/conv/conv_package.vhd
add_fileset_file window_gen.vhd VHDL PATH src/conv/window_gen.vhd


# 
# parameters
# 
add_parameter COLS INTEGER 640
set_parameter_property COLS DEFAULT_VALUE 640
set_parameter_property COLS DISPLAY_NAME COLS
set_parameter_property COLS TYPE INTEGER
set_parameter_property COLS UNITS None
set_parameter_property COLS HDL_PARAMETER true
add_parameter LINES INTEGER 480
set_parameter_property LINES DEFAULT_VALUE 480
set_parameter_property LINES DISPLAY_NAME LINES
set_parameter_property LINES TYPE INTEGER
set_parameter_property LINES UNITS None
set_parameter_property LINES HDL_PARAMETER true
add_parameter NBITS_ADDR INTEGER 32
set_parameter_property NBITS_ADDR DEFAULT_VALUE 32
set_parameter_property NBITS_ADDR DISPLAY_NAME NBITS_ADDR
set_parameter_property NBITS_ADDR TYPE INTEGER
set_parameter_property NBITS_ADDR UNITS None
set_parameter_property NBITS_ADDR HDL_PARAMETER true
add_parameter NBITS_COLS INTEGER 12
set_parameter_property NBITS_COLS DEFAULT_VALUE 12
set_parameter_property NBITS_COLS DISPLAY_NAME NBITS_COLS
set_parameter_property NBITS_COLS TYPE INTEGER
set_parameter_property NBITS_COLS UNITS None
set_parameter_property NBITS_COLS HDL_PARAMETER true
add_parameter NBITS_LINES INTEGER 12
set_parameter_property NBITS_LINES DEFAULT_VALUE 12
set_parameter_property NBITS_LINES DISPLAY_NAME NBITS_LINES
set_parameter_property NBITS_LINES TYPE INTEGER
set_parameter_property NBITS_LINES UNITS None
set_parameter_property NBITS_LINES HDL_PARAMETER true


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
# connection point slave
# 
add_interface slave avalon end
set_interface_property slave addressUnits WORDS
set_interface_property slave associatedClock clock
set_interface_property slave associatedReset reset_sink
set_interface_property slave bitsPerSymbol 8
set_interface_property slave burstOnBurstBoundariesOnly false
set_interface_property slave burstcountUnits WORDS
set_interface_property slave explicitAddressSpan 0
set_interface_property slave holdTime 0
set_interface_property slave linewrapBursts false
set_interface_property slave maximumPendingReadTransactions 1
set_interface_property slave maximumPendingWriteTransactions 0
set_interface_property slave readLatency 0
set_interface_property slave readWaitTime 1
set_interface_property slave setupTime 0
set_interface_property slave timingUnits Cycles
set_interface_property slave writeWaitTime 0
set_interface_property slave ENABLED true
set_interface_property slave EXPORT_OF ""
set_interface_property slave PORT_NAME_MAP ""
set_interface_property slave CMSIS_SVD_VARIABLES ""
set_interface_property slave SVD_ADDRESS_GROUP ""

add_interface_port slave slave_chipselect chipselect Input 1
add_interface_port slave slave_read read Input 1
add_interface_port slave slave_write write Input 1
add_interface_port slave slave_address address Input 4
add_interface_port slave slave_writedata writedata Input 32
add_interface_port slave slave_waitrequest waitrequest Output 1
add_interface_port slave slave_readdatavalid readdatavalid Output 1
add_interface_port slave slave_readdata readdata Output 32
set_interface_assignment slave embeddedsw.configuration.isFlash 0
set_interface_assignment slave embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment slave embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment slave embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avalon_master
# 
add_interface avalon_master avalon start
set_interface_property avalon_master addressUnits SYMBOLS
set_interface_property avalon_master associatedClock clock
set_interface_property avalon_master associatedReset reset_sink
set_interface_property avalon_master bitsPerSymbol 8
set_interface_property avalon_master burstOnBurstBoundariesOnly false
set_interface_property avalon_master burstcountUnits WORDS
set_interface_property avalon_master doStreamReads false
set_interface_property avalon_master doStreamWrites false
set_interface_property avalon_master holdTime 0
set_interface_property avalon_master linewrapBursts false
set_interface_property avalon_master maximumPendingReadTransactions 0
set_interface_property avalon_master maximumPendingWriteTransactions 0
set_interface_property avalon_master readLatency 0
set_interface_property avalon_master readWaitTime 1
set_interface_property avalon_master setupTime 0
set_interface_property avalon_master timingUnits Cycles
set_interface_property avalon_master writeWaitTime 0
set_interface_property avalon_master ENABLED true
set_interface_property avalon_master EXPORT_OF ""
set_interface_property avalon_master PORT_NAME_MAP ""
set_interface_property avalon_master CMSIS_SVD_VARIABLES ""
set_interface_property avalon_master SVD_ADDRESS_GROUP ""

add_interface_port avalon_master masterrd_waitrequest waitrequest Input 1
add_interface_port avalon_master masterrd_readdatavalid readdatavalid Input 1
add_interface_port avalon_master masterrd_readdata readdata Input 8
add_interface_port avalon_master masterrd_address address Output nbits_addr
add_interface_port avalon_master masterrd_read read Output 1


# 
# connection point avalon_master_1
# 
add_interface avalon_master_1 avalon start
set_interface_property avalon_master_1 addressUnits SYMBOLS
set_interface_property avalon_master_1 associatedClock clock
set_interface_property avalon_master_1 associatedReset reset_sink
set_interface_property avalon_master_1 bitsPerSymbol 8
set_interface_property avalon_master_1 burstOnBurstBoundariesOnly false
set_interface_property avalon_master_1 burstcountUnits WORDS
set_interface_property avalon_master_1 doStreamReads false
set_interface_property avalon_master_1 doStreamWrites false
set_interface_property avalon_master_1 holdTime 0
set_interface_property avalon_master_1 linewrapBursts false
set_interface_property avalon_master_1 maximumPendingReadTransactions 0
set_interface_property avalon_master_1 maximumPendingWriteTransactions 0
set_interface_property avalon_master_1 readLatency 0
set_interface_property avalon_master_1 readWaitTime 1
set_interface_property avalon_master_1 setupTime 0
set_interface_property avalon_master_1 timingUnits Cycles
set_interface_property avalon_master_1 writeWaitTime 0
set_interface_property avalon_master_1 ENABLED true
set_interface_property avalon_master_1 EXPORT_OF ""
set_interface_property avalon_master_1 PORT_NAME_MAP ""
set_interface_property avalon_master_1 CMSIS_SVD_VARIABLES ""
set_interface_property avalon_master_1 SVD_ADDRESS_GROUP ""

add_interface_port avalon_master_1 masterwr_address address Output nbits_addr
add_interface_port avalon_master_1 masterwr_waitrequest waitrequest Input 1
add_interface_port avalon_master_1 masterwr_write write Output 1
add_interface_port avalon_master_1 masterwr_writedata writedata Output 8


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

