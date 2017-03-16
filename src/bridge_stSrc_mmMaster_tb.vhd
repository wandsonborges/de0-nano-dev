-------------------------------------------------------------------------------
-- Title      : Testbench for design "bridge_stSrc_mmMaster"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bridge_stSrc_mmMaster_tb.vhd
-- Author     :   <Rodrigo Rodrigues@TANENBAUM>
-- Company    : 
-- Created    : 2017-03-14
-- Last update: 2017-03-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-03-14  1.0      Rodrigo Rodrigues	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity bridge_stSrc_mmMaster_tb is

end entity bridge_stSrc_mmMaster_tb;

-------------------------------------------------------------------------------

architecture tb of bridge_stSrc_mmMaster_tb is

  -- component generics
  constant COLS        : integer := 640;
  constant LINES       : integer := 480;
  constant NBITS_ADDR  : integer := 32;
  constant NBITS_DATA  : integer := 8;
  constant NBITS_BURST : integer := 4;
  constant BURST       : integer := 8;

  -- component ports
  signal clk, clk_mem        : std_logic := '1';
  signal rst_n               : std_logic := '0';
  signal master_waitrequest  : std_logic := '0';
  signal master_address      : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal master_write        : std_logic;
  signal master_writedata    : std_logic_vector(NBITS_DATA-1 downto 0);
  signal st_startofpacket    : std_logic;
  signal st_endofpacket      : std_logic;
  signal st_datain           : std_logic_vector(NBITS_DATA-1 downto 0);
  signal st_datavalid        : std_logic;
  signal st_ready            : std_logic;


begin  -- architecture tb

  -- component instantiation
  DUT: entity work.bridge_stSrc_mmMaster
    generic map (
      COLS        => COLS,
      LINES       => LINES,
      NBITS_ADDR  => NBITS_ADDR,
      NBITS_DATA  => NBITS_DATA,
      NBITS_BURST => NBITS_BURST,
      BURST       => BURST)
    port map (
      clk                => clk,
      clk_mem            => clk_mem,
      rst_n              => rst_n,
      master_waitrequest => master_waitrequest,
      master_address     => master_address,
      master_write       => master_write,
      master_writedata   => master_writedata,
      st_startofpacket   => st_startofpacket,
      st_endofpacket     => st_endofpacket,
      st_datain          => st_datain,
      st_datavalid       => st_datavalid,
      st_ready           => st_ready);

  lupa_fake_1: entity work.lupa_fake
    generic map (
      ROWS => 4,
      COLS => 32,
      FOT  => 8,
      ROT  => 4)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      en            => st_ready,
      frame_valid   => open,
      line_valid    => open,
      data_out      => st_datain,
      data_valid    => st_datavalid,
      startofpacket => st_startofpacket,
      endofpacket   => st_endofpacket);

  -- clock generation
  -- Clk <= not Clk after 10 ns;
  -- clk_mem <= not clk_mem after 10 ns; --not clk_mem after 10 ns;
  -- master_waitrequest <= not master_waitrequest after 100 ns;

  rst_n <= '1' after 60 ns;
  
  WaveGen_Proc: process
  begin
    Clk <= '1';
    wait for 20 ns; -- Clk'event and Clk = '1';
    Clk <= '0';
    wait for 20 ns;
  end process WaveGen_Proc;


  WaveGen_Proc3: process
  begin
    clk_mem <= '1';
    wait for 10 ns; -- Clk'event and Clk = '1';
    clk_mem <= '0';
    wait for 10 ns;
  end process WaveGen_Proc3;

  WaveGen_Proc2: process
  begin
    master_waitrequest <= '1';
    wait for 500 ns; -- Clk'event and Clk = '1';
    master_waitrequest <= '0';
    wait for 500 ns;
  end process WaveGen_Proc2;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration bridge_stSrc_mmMaster_tb_tb_cfg of bridge_stSrc_mmMaster_tb is
  for tb
  end for;
end bridge_stSrc_mmMaster_tb_tb_cfg;

-------------------------------------------------------------------------------
