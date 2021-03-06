# TCL File Generated by Component Editor 16.1
# Thu Feb 28 15:17:41 BRT 2019
# DO NOT MODIFY


# 
# homography_dma "homography_dma" v1.0
#  2019.02.28.15:17:41
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module homography_dma
# 
set_module_property DESCRIPTION ""
set_module_property NAME homography_dma
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME homography_dma
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL homography_avalon
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file homography_avalon.vhd VHDL PATH src/homography/homography_avalon.vhd TOP_LEVEL_FILE
add_fileset_file homography_core.vhd VHDL PATH src/homography/homography_core.vhd


# 
# parameters
# 
add_parameter COLS INTEGER 640
set_parameter_property COLS DEFAULT_VALUE 640
set_parameter_property COLS DISPLAY_NAME COLS
set_parameter_property COLS TYPE INTEGER
set_parameter_property COLS UNITS None
set_parameter_property COLS ALLOWED_RANGES -2147483648:2147483647
set_parameter_property COLS HDL_PARAMETER true
add_parameter LINES INTEGER 480
set_parameter_property LINES DEFAULT_VALUE 480
set_parameter_property LINES DISPLAY_NAME LINES
set_parameter_property LINES TYPE INTEGER
set_parameter_property LINES UNITS None
set_parameter_property LINES ALLOWED_RANGES -2147483648:2147483647
set_parameter_property LINES HDL_PARAMETER true
add_parameter HOMOG_BITS_INT INTEGER 12
set_parameter_property HOMOG_BITS_INT DEFAULT_VALUE 12
set_parameter_property HOMOG_BITS_INT DISPLAY_NAME HOMOG_BITS_INT
set_parameter_property HOMOG_BITS_INT TYPE INTEGER
set_parameter_property HOMOG_BITS_INT UNITS None
set_parameter_property HOMOG_BITS_INT ALLOWED_RANGES -2147483648:2147483647
set_parameter_property HOMOG_BITS_INT HDL_PARAMETER true
add_parameter HOMOG_BITS_FRAC INTEGER 20
set_parameter_property HOMOG_BITS_FRAC DEFAULT_VALUE 20
set_parameter_property HOMOG_BITS_FRAC DISPLAY_NAME HOMOG_BITS_FRAC
set_parameter_property HOMOG_BITS_FRAC TYPE INTEGER
set_parameter_property HOMOG_BITS_FRAC UNITS None
set_parameter_property HOMOG_BITS_FRAC ALLOWED_RANGES -2147483648:2147483647
set_parameter_property HOMOG_BITS_FRAC HDL_PARAMETER true
add_parameter NBITS_ADDR INTEGER 32
set_parameter_property NBITS_ADDR DEFAULT_VALUE 32
set_parameter_property NBITS_ADDR DISPLAY_NAME NBITS_ADDR
set_parameter_property NBITS_ADDR TYPE INTEGER
set_parameter_property NBITS_ADDR UNITS None
set_parameter_property NBITS_ADDR ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_ADDR HDL_PARAMETER true
add_parameter NBITS_DATA INTEGER 8
set_parameter_property NBITS_DATA DEFAULT_VALUE 8
set_parameter_property NBITS_DATA DISPLAY_NAME NBITS_DATA
set_parameter_property NBITS_DATA TYPE INTEGER
set_parameter_property NBITS_DATA UNITS None
set_parameter_property NBITS_DATA ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_DATA HDL_PARAMETER true
add_parameter NBITS_COLS INTEGER 12
set_parameter_property NBITS_COLS DEFAULT_VALUE 12
set_parameter_property NBITS_COLS DISPLAY_NAME NBITS_COLS
set_parameter_property NBITS_COLS TYPE INTEGER
set_parameter_property NBITS_COLS UNITS None
set_parameter_property NBITS_COLS ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_COLS HDL_PARAMETER true
add_parameter NBITS_LINES INTEGER 12
set_parameter_property NBITS_LINES DEFAULT_VALUE 12
set_parameter_property NBITS_LINES DISPLAY_NAME NBITS_LINES
set_parameter_property NBITS_LINES TYPE INTEGER
set_parameter_property NBITS_LINES UNITS None
set_parameter_property NBITS_LINES ALLOWED_RANGES -2147483648:2147483647
set_parameter_property NBITS_LINES HDL_PARAMETER true
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
add_parameter HOMOG_DELAY_CYCLES INTEGER 8
set_parameter_property HOMOG_DELAY_CYCLES DEFAULT_VALUE 8
set_parameter_property HOMOG_DELAY_CYCLES DISPLAY_NAME HOMOG_DELAY_CYCLES
set_parameter_property HOMOG_DELAY_CYCLES TYPE INTEGER
set_parameter_property HOMOG_DELAY_CYCLES UNITS None
set_parameter_property HOMOG_DELAY_CYCLES ALLOWED_RANGES -2147483648:2147483647
set_parameter_property HOMOG_DELAY_CYCLES HDL_PARAMETER true
add_parameter BURST INTEGER 8
set_parameter_property BURST DEFAULT_VALUE 8
set_parameter_property BURST DISPLAY_NAME BURST
set_parameter_property BURST TYPE INTEGER
set_parameter_property BURST UNITS None
set_parameter_property BURST ALLOWED_RANGES -2147483648:2147483647
set_parameter_property BURST HDL_PARAMETER true
add_parameter ADDR_READ STD_LOGIC_VECTOR 952107008 ""
set_parameter_property ADDR_READ DEFAULT_VALUE 952107008
set_parameter_property ADDR_READ DISPLAY_NAME ADDR_READ
set_parameter_property ADDR_READ WIDTH 32
set_parameter_property ADDR_READ TYPE STD_LOGIC_VECTOR
set_parameter_property ADDR_READ UNITS None
set_parameter_property ADDR_READ DESCRIPTION ""
set_parameter_property ADDR_READ HDL_PARAMETER true
add_parameter ADDR_WRITE STD_LOGIC_VECTOR 944766976
set_parameter_property ADDR_WRITE DEFAULT_VALUE 944766976
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
set_interface_property avalon_master maximumPendingReadTransactions 16
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
add_interface_port avalon_master masterrd_readdata readdata Input nbits_data
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
add_interface_port avalon_master_1 masterwr_writedata writedata Output nbits_data


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

