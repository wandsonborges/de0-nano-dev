
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package conv_package is

constant NBITS_DATA : integer := 8;
constant NBITS_KERNEL_DATA : integer := 8;

constant NBITS_KERNEL_FRAC : integer := 0;
 
constant KERNEL_W : integer := 3;
constant KERNEL_H : integer := 3;

constant KERNEL_ELEMENTS : integer := KERNEL_H*KERNEL_W;

constant NBITS_INTERNAL_RESULT : integer := NBITS_DATA + NBITS_KERNEL_DATA + 1;

type kernel_line_type is array (0 to KERNEL_W-1) of std_logic_vector(NBITS_KERNEL_DATA-1 downto 0);
type kernel_type is array (0 to KERNEL_H-1) of kernel_line_type;

type window_line_type is array (0 to KERNEL_W-1) of std_logic_vector(NBITS_DATA-1 downto 0);
type window_type is array (0 to KERNEL_H-1) of window_line_type;

type result_line_type is array (0 to KERNEL_W-1) of std_logic_vector(NBITS_INTERNAL_RESULT-1 downto 0);
type result_type is array (0 to KERNEL_H-1) of result_line_type;

type window_unsig_line_type is array (0 to KERNEL_W-1) of std_logic_vector(NBITS_DATA downto 0);
type window_unsig_type is array (0 to KERNEL_H-1) of window_unsig_line_type;


end conv_package;
