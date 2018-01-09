-------------------------------------------------------------------------------
-- Title      : Testbench for design "homography_core"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : homography_core_tb.vhd
-- Author     :   <rodrigo@thomson>
-- Company    : 
-- Created    : 2017-06-06
-- Last update: 2017-06-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-06-06  1.0      rodrigo	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-------------------------------------------------------------------------------

entity homography_core_tb is

end entity homography_core_tb;

-------------------------------------------------------------------------------

architecture tb of homography_core_tb is

  -- component generics
  constant WIDTH           : integer := 32;
  constant HEIGHT          : integer := 24;
  constant CICLOS_LATENCIA : integer := 8;
  constant WW              : integer := 8;
  constant HW              : integer := 7;
  constant n_bits_int      : integer := 12;
  constant n_bits_frac     : integer := 20;

  -- component ports
  signal rst_n          : std_logic := '0';
  signal clear          : std_logic;
  signal inc_addr       : std_logic := '0';
  signal sw             : std_logic_vector(17 downto 0) := (others => '0');
  signal x_in           : std_logic_vector(WW downto 0) := (others => '0');
  signal y_in           : std_logic_vector(HW downto 0) := (others => '0');
  signal write_en       : std_logic_vector(0 downto 0);
  signal write_en_delay : std_logic_vector(0 downto 0);
  signal x_out          : std_logic_vector(WW downto 0);
  signal last_data      : std_logic;
  signal y_out          : std_logic_vector(HW downto 0);

  -- clock
  signal Clk : std_logic := '1';

begin  -- architecture tb

  -- component instantiation
  DUT: entity work.homography_core
    generic map (
      WIDTH           => WIDTH,
      HEIGHT          => HEIGHT,
      CICLOS_LATENCIA => CICLOS_LATENCIA,
      WW              => WW,
      HW              => HW,
      n_bits_int      => n_bits_int,
      n_bits_frac     => n_bits_frac)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      clear          => clear,
      inc_addr       => inc_addr,
      sw             => sw,
      x_in           => x_in,
      y_in           => y_in,
      last_data      => last_data,
      write_en       => write_en,
      write_en_delay => write_en_delay,
      x_out          => x_out,
      y_out          => y_out);

  -- clock generation
  Clk <= not Clk after 10 ns;
  rst_n <= '1' after 60 ns;
  inc_addr <= '1' after 80 ns;
  -- waveform generation
  WaveGen_Proc: process
  begin
    if inc_addr = '1' then
    if (unsigned(x_in) = WIDTH-1 and unsigned(y_in) = HEIGHT-1) then
          x_in <= (others => '0');
          y_in <= (others => '0');
        elsif (unsigned(x_in) = WIDTH-1) then
          x_in <= (others => '0');
          y_in <= std_logic_vector(unsigned(y_in) + 1);
        else
          x_in <= std_logic_vector(unsigned(x_in) + 1);
        end if;
    end if;
    
        
                 
                          
    -- insert signal assignments here

    wait until Clk = '1';
  end process WaveGen_Proc;

  

end architecture tb;

-------------------------------------------------------------------------------

configuration homography_core_tb_tb_cfg of homography_core_tb is
  for tb
  end for;
end homography_core_tb_tb_cfg;

-------------------------------------------------------------------------------
