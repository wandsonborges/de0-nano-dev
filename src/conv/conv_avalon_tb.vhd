-------------------------------------------------------------------------------
-- Title      : Testbench for design "conv_avalon"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : conv_avalon_tb.vhd
-- Author     :   <rodrigo@shannon>
-- Company    : 
-- Created    : 2018-05-17
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
-- 2018-05-17  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

LIBRARY lpm;
USE lpm.lpm_components.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

use work.conv_package.all;

-------------------------------------------------------------------------------

entity conv_avalon_tb is

end entity conv_avalon_tb;

-------------------------------------------------------------------------------

architecture tb of conv_avalon_tb is

  -- component generics
  constant MAX_COLS    : integer := 48;
  constant NBITS_ADDR  : integer := 32;
  constant NBITS_COLS  : integer := 12;
  constant NBITS_LINES : integer := 12;


  -- component ports
  signal clk, rst_n             : std_logic := '0';
  signal masterwr_waitrequest   : std_logic := '0';
  signal masterwr_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal masterwr_write         : std_logic := '0';
  signal masterwr_writedata     : std_logic_vector(NBITS_DATA-1 downto 0);
  signal masterrd_waitrequest   : std_logic := '0';
  signal masterrd_readdatavalid : std_logic;
  signal masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');
  signal masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal masterrd_read          : std_logic;
  signal slave_chipselect       : std_logic;
  signal slave_read             : std_logic;
  signal slave_write            : std_logic;
  signal slave_address          : std_logic_vector(4 downto 0);
  signal slave_writedata        : std_logic_vector(31 downto 0);
  signal slave_waitrequest      : std_logic;
  signal slave_readdatavalid    : std_logic;
  signal slave_readdata         : std_logic_vector(31 downto 0);

  -- clock


begin  -- architecture tb

  -- component instantiation
  DUT: entity work.conv_avalon
    generic map (
      NBITS_ADDR  => NBITS_ADDR,
      NBITS_COLS  => NBITS_COLS,
      NBITS_LINES => NBITS_LINES)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterwr_waitrequest   => masterwr_waitrequest,
      masterwr_address       => masterwr_address,
      masterwr_write         => masterwr_write,
      masterwr_writedata     => masterwr_writedata,
      masterrd_waitrequest   => masterrd_waitrequest,
      masterrd_readdatavalid => masterrd_readdatavalid,
      masterrd_readdata      => masterrd_readdata,
      masterrd_address       => masterrd_address,
      masterrd_read          => masterrd_read,
      slave_chipselect       => slave_chipselect,
      slave_read             => slave_read,
      slave_write            => slave_write,
      slave_address          => slave_address,
      slave_writedata        => slave_writedata,
      slave_waitrequest      => slave_waitrequest,
      slave_readdatavalid    => slave_readdatavalid,
      slave_readdata         => slave_readdata);

  -- clock generation
  Clk <= not Clk after 10 ns;
  rst_n <= '1' after 60 ns;

  masterrd_waitrequest <= '0';

  slave_address <= (others => '0');
  slave_writedata <= (others => '1');
  slave_write <= '1' after 80 ns;
  slave_chipselect <= '1';
  -- waveform generation
  WaveGen_Proc: process
  begin
    masterrd_readdatavalid <= masterrd_read;
    -- insert signal assignments here
    if (masterrd_readdatavalid = '1') then
      masterrd_readdata <= std_logic_vector(unsigned(masterrd_readdata) + 1);
    end if;    
    wait until Clk = '1';
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration conv_avalon_tb_tb_cfg of conv_avalon_tb is
  for tb
  end for;
end conv_avalon_tb_tb_cfg;

-------------------------------------------------------------------------------
