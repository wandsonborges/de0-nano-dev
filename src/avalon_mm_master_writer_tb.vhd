-------------------------------------------------------------------------------
-- Title      : Testbench for design "avalon_mm_master_writer"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : avalon_mm_master_writer_tb.vhd
-- Author     :   <rodrigo@thomson>
-- Company    : 
-- Created    : 2016-11-18
-- Last update: 2016-11-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2016-11-18  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity avalon_mm_master_writer_tb is

end entity avalon_mm_master_writer_tb;

-------------------------------------------------------------------------------

architecture tb of avalon_mm_master_writer_tb is

  -- component generics
  constant ADDR_W    : integer := 32;
  constant DATA_W    : integer := 32;
  constant BURST_W   : integer := 8;
  constant BURST     : integer := 8;
  constant BYTE_EN_W : integer := 4;

  -- component ports
  signal rst         : std_logic := '1';
  signal waitrequest : std_logic := '0';
  signal address     : std_logic_vector(ADDR_W-1 downto 0);
  signal write       : std_logic;
  signal writedata   : std_logic_vector(DATA_W-1 downto 0);
  signal burstcount  : std_logic_vector(BURST_W-1 downto 0);
  signal byteenable  : std_logic_vector(BYTE_EN_W-1 downto 0);

  -- clock
  signal clk : std_logic := '1';

begin  -- architecture tb

  -- component instantiation
  DUT: entity work.avalon_mm_master_writer
    generic map (
      ADDR_W    => ADDR_W,
      DATA_W    => DATA_W,
      BURST_W   => BURST_W,
      BURST     => BURST,
      BYTE_EN_W => BYTE_EN_W)
    port map (
      clk         => clk,
      rst         => rst,
      waitrequest => waitrequest,
      address     => address,
      write       => write,
      writedata   => writedata,
      burstcount  => burstcount,
      byteenable  => byteenable);

  -- clock generation
  clk <= not clk after 10 ns;
  rst <= '0' after 60 ns;
  waitrequest <= not waitrequest after 40 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until Clk = '1';
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration avalon_mm_master_writer_tb_tb_cfg of avalon_mm_master_writer_tb is
  for tb
  end for;
end avalon_mm_master_writer_tb_tb_cfg;

-------------------------------------------------------------------------------
