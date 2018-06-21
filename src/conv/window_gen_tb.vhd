-------------------------------------------------------------------------------
-- Title      : Testbench for design "window_gen"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : window_gen_tb.vhd
-- Author     :   <rodrigo@shannon>
-- Company    : 
-- Created    : 2018-05-10
-- Last update: 2018-06-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-05-10  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

LIBRARY lpm;
USE lpm.lpm_components.all;


-------------------------------------------------------------------------------

entity window_gen_tb is

end entity window_gen_tb;

-------------------------------------------------------------------------------

architecture tb of window_gen_tb is

  -- component generics
  constant NBITS_COLS  : integer := 12;
  constant NBITS_LINES : integer := 12;

  -- component ports
  signal clk, rst_n   : std_logic := '0';
  signal start_conv   : std_logic := '0';
  signal pxl_valid    : std_logic := '0';
  signal pxl_data     : STD_LOGIC_VECTOR(NBITS_DATA-1 downto 0) := (others => '0');
  signal window_valid : std_logic;
  signal window_data  : window_type;
  signal img_col_size : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0);
  signal img_line_size : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0);    
    


begin  -- architecture tb

  -- component instantiation
  DUT: entity work.window_gen
    generic map (
      NBITS_COLS  => NBITS_COLS,
      NBITS_LINES => NBITS_LINES)
    port map (
      clk          => clk,
      rst_n        => rst_n,
      start_conv   => start_conv,
      pxl_valid    => pxl_valid,
      pxl_data     => pxl_data,
      img_line_size => img_line_size,
      img_col_size  => img_col_size,
      window_valid => window_valid,
      window_data  => window_data);

  -- clock generation
  Clk <= not Clk after 10 ns;
  rst_n <= '1' after 60 ns;
  pxl_valid <= '1' after 120 ns;
  start_conv <= '1' after 100 ns;

  img_line_size <= x"1e0";
  img_col_size <= x"280";

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    
    wait until Clk = '1';
    if (pxl_valid = '1') then
      pxl_data <= STD_LOGIC_VECTOR(unsigned(pxl_data) + 1);
    else
      pxl_data <= pxl_data;
    end if;
    
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration window_gen_tb_tb_cfg of window_gen_tb is
  for tb
  end for;
end window_gen_tb_tb_cfg;

-------------------------------------------------------------------------------
