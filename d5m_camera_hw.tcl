# TCL File Generated by Component Editor 16.1
# Wed Mar 22 18:50:51 BRT 2017
# DO NOT MODIFY


# 
# d5m_camera "d5m_camera" v1.0
#  2017.03.22.18:50:51
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.0


# 
# module d5m_camera
# 
set_module_property DESCRIPTION ""
set_module_property NAME d5m_camera
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME d5m_camera
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL d5m_controller_v
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file d5m_controller.v VERILOG PATH src/d5m_periph/d5m_controller.v TOP_LEVEL_FILE
add_fileset_file I2C_CCD_Config.v VERILOG PATH src/d5m_periph/I2C_CCD_Config.v
add_fileset_file Reset_Delay.v VERILOG PATH src/d5m_periph/Reset_Delay.v
add_fileset_file i2c_controller.v VERILOG PATH src/d5m_periph/i2c_controller.v


# 
# parameters
# 


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
# connection point avalon_streaming_source
# 
add_interface avalon_streaming_source avalon_streaming start
set_interface_property avalon_streaming_source associatedClock clock
set_interface_property avalon_streaming_source associatedReset reset_sink
set_interface_property avalon_streaming_source dataBitsPerSymbol 8
set_interface_property avalon_streaming_source errorDescriptor ""
set_interface_property avalon_streaming_source firstSymbolInHighOrderBits true
set_interface_property avalon_streaming_source maxChannel 0
set_interface_property avalon_streaming_source readyLatency 0
set_interface_property avalon_streaming_source ENABLED true
set_interface_property avalon_streaming_source EXPORT_OF ""
set_interface_property avalon_streaming_source PORT_NAME_MAP ""
set_interface_property avalon_streaming_source CMSIS_SVD_VARIABLES ""
set_interface_property avalon_streaming_source SVD_ADDRESS_GROUP ""

add_interface_port avalon_streaming_source data_out data Output 8
add_interface_port avalon_streaming_source data_valid valid Output 1
add_interface_port avalon_streaming_source endofpacket endofpacket Output 1
add_interface_port avalon_streaming_source startofpacket startofpacket Output 1
add_interface_port avalon_streaming_source ready ready Input 1


# 
# connection point conduit_end
# 
add_interface conduit_end conduit end
set_interface_property conduit_end associatedClock clock
set_interface_property conduit_end associatedReset ""
set_interface_property conduit_end ENABLED true
set_interface_property conduit_end EXPORT_OF ""
set_interface_property conduit_end PORT_NAME_MAP ""
set_interface_property conduit_end CMSIS_SVD_VARIABLES ""
set_interface_property conduit_end SVD_ADDRESS_GROUP ""

add_interface_port conduit_end data_in datain Input 8
add_interface_port conduit_end frame_valid fvalid Input 1
add_interface_port conduit_end line_valid lvalid Input 1
add_interface_port conduit_end start start Input 1
add_interface_port conduit_end rst_sensor rst_sensor Output 1
add_interface_port conduit_end sclk sclk Output 1
add_interface_port conduit_end sdata sdata Bidir 1
add_interface_port conduit_end trigger trigger Output 1
add_interface_port conduit_end sys_clk sysclk Input 1


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

