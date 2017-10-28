-------------------------------------------------------------------------------
-- Title      : Testbench for design "readPacketsAvalon"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : readPacketsAvalon_tb.vhd
-- Author     :   <rodrigo@archlinux>
-- Company    : 
-- Created    : 2017-10-21
-- Last update: 2017-10-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-10-21  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
-------------------------------------------------------------------------------

entity readPacketsAvalon_tb is

end entity readPacketsAvalon_tb;

-------------------------------------------------------------------------------

architecture tb of readPacketsAvalon_tb is

  -- component generics
  constant NBITS_ADDR    : integer := 32;
  constant NBITS_DATA    : integer := 32;
  constant NBITS_PACKETS : integer := 32;
  constant FIFO_SIZE     : integer := 256;
  constant BURST         : integer := 8;

  -- component ports
  signal rst_n             : std_logic := '0';
  signal masterrd_waitrequest   : std_logic := '0';
  signal masterrd_chipselect   : std_logic := '0';
  signal masterrd_readdatavalid : std_logic := '0';
  signal masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');
  signal masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal masterrd_read          : std_logic := '0';
  signal enable_read            : std_logic := '0';
  signal packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal get_read_data          : std_logic;
  signal data_ready             : std_logic;
  signal data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal burst_en               : std_logic;

  -- clock
  signal Clk : std_logic := '1';

begin  -- architecture tb

  -- component instantiation
  DUT: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE,
      BURST         => BURST)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_chipselect    => masterrd_chipselect,
      masterrd_waitrequest   => masterrd_waitrequest,
      masterrd_readdatavalid => masterrd_readdatavalid,
      masterrd_readdata      => masterrd_readdata,
      masterrd_address       => masterrd_address,
      masterrd_read          => masterrd_read,
      enable_read            => enable_read,
      packets_to_read        => packets_to_read,
      address_init           => address_init,
      get_read_data          => get_read_data,
      data_ready             => data_ready,
      data_out               => data_out,
      burst_en               => burst_en);

  -- clock generation
  Clk <= not Clk after 10 ns;

  masterrd_waitrequest <= '0';
  rst_n <= '1' after 60 ns;

  packets_to_read <= x"00000030";

  enable_read <= '1' after 100 ns;

  masterrd_chipselect <= '1';
  masterrd_readdatavalid <= not masterrd_readdatavalid after 100 ns;
  
  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    if masterrd_readdatavalid = '1' then
      masterrd_readdata <= std_logic_vector(UNSIGNED(masterrd_readdata) + 1);
      end if;
    wait until Clk = '1';
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration readPacketsAvalon_tb_tb_cfg of readPacketsAvalon_tb is
  for tb
  end for;
end readPacketsAvalon_tb_tb_cfg;

-------------------------------------------------------------------------------
