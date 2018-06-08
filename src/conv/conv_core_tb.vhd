-------------------------------------------------------------------------------
-- Title      : Testbench for design "conv_core"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : conv_core_tb.vhd
-- Author     :   <rodrigo@shannon>
-- Company    : 
-- Created    : 2018-05-03
-- Last update: 2018-05-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-05-03  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

-------------------------------------------------------------------------------

entity conv_core_tb is

end entity conv_core_tb;

-------------------------------------------------------------------------------

architecture tb of conv_core_tb is

  -- component ports
  signal kernel           : kernel_type;
  signal data_in          : window_type;
  signal data_in_valid    : std_logic;
  signal pxl_result       : std_logic_vector(NBITS_DATA-1 downto 0);
  signal pxl_result_valid : std_logic;

  -- clock
  signal Clk, rst_n : std_logic := '0';

begin  -- architecture tb

  -- component instantiation
  DUT: entity work.conv_core
    port map (
      clk              => clk,
      rst_n            => rst_n,
      kernel           => kernel,
      data_in          => data_in,
      data_in_valid    => data_in_valid,
      pxl_result       => pxl_result,
      pxl_result_valid => pxl_result_valid);

  -- clock generation
  Clk <= not Clk after 10 ns;
  rst_n <= '1' after 60 ns;


-- kernel values
  kernel(0)(0) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(0)(1) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(0)(2) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));

  kernel(1)(0) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(1)(1) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(1)(2) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));

  kernel(2)(0) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(2)(1) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));
  kernel(2)(2) <= std_logic_vector(to_signed(-28, NBITS_KERNEL_DATA));


--window data
  data_in(0)(0) <= std_logic_vector(to_signed(10, NBITS_DATA));
  data_in(0)(1) <= std_logic_vector(to_signed(10, NBITS_DATA));
  data_in(0)(2) <= std_logic_vector(to_signed(10, NBITS_DATA));

  data_in(1)(0) <= std_logic_vector(to_signed(10, NBITS_DATA));
  data_in(1)(1) <= std_logic_vector(to_signed(20, NBITS_DATA));
  data_in(1)(2) <= std_logic_vector(to_signed(10, NBITS_DATA));

  data_in(2)(0) <= std_logic_vector(to_signed(10, NBITS_DATA));
  data_in(2)(1) <= std_logic_vector(to_signed(20, NBITS_DATA));
  data_in(2)(2) <= std_logic_vector(to_signed(10, NBITS_DATA));

  

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until Clk = '1';
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration conv_core_tb_tb_cfg of conv_core_tb is
  for tb
  end for;
end conv_core_tb_tb_cfg;

-------------------------------------------------------------------------------
