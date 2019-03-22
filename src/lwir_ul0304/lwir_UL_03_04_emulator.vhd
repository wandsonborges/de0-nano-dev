-- Author     :   <rodrigo@thomson>
-- Company    : 
-- Created    : 2015-08-07
-- Last update: 2019-02-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: EMULADOR Sensor Termal LWIR UL 03 04 1
-------------------------------------------------------------------------------
-- Copyright (c) 2015 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-08-07  1.0      rodrigo	Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--use work.megafunc_pkg.all;


entity lwir_UL_03_04_emulator is
  generic (
    N_BITS_COL     : integer          := 9;
    N_BITS_LIN     : integer          := 9;
    NUM_COLS       : integer          := 384;
    NUM_LINES      : integer          := 288;
    N_BITS_PXL     : integer          := 8
    );

  port (
    clk, rst_n        : in  std_logic;
    en                : in  std_logic;
    sens_syt          : in  std_logic; --frame sync
    sens_syl          : in  std_logic; --line sync
    sens_syp          : in  std_logic; --pxl sync
    pxl_out           : out  std_logic_vector(N_BITS_PXL-1 downto 0)
    );

end entity lwir_UL_03_04_emulator;

architecture bhv of lwir_UL_03_04_emulator is

signal syt_f1, syt_f2 : std_logic := '0';  
signal syl_f1, syl_f2 : std_logic := '0';  
signal syp_f1, syp_f2 : std_logic := '0';

signal syp_edge : std_logic := '0';
signal syl_edge : std_logic := '0';

signal line_counter : integer := 0;
signal col_counter : integer := 0;
signal frame_counter : unsigned(7 downto 0) := (others => '0');

signal pxl_aux  : std_logic_vector(N_BITS_PXL-1 downto 0) := (others => '0');

begin  -- architecture bhv

dff_proc: process (clk, rst_n) is
begin  -- process dff_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    syt_f1 <= '0';
    syt_f2 <= '0';
    syl_f1 <= '0';
    syl_f2 <= '0';
    syp_f1 <= '0';
    syp_f2 <= '0';
    frame_counter <= (others => '0');
  elsif clk'event and clk = '1' then  -- rising clock edge
    syt_f1 <= sens_syt;
    syt_f2 <= syt_f1;
    syl_f1 <= sens_syl;
    syl_f2 <= syl_f1;
    syp_f1 <= sens_syp;
    syp_f2 <= syp_f1;

    if (syt_f1 = '0' and sens_syt = '1') then
      frame_counter <= frame_counter + 1;
    else
      frame_counter <= frame_counter;
    end if;
    
  end if;
end process dff_proc;

syp_edge <= '1' when syp_f2 = '0' and syp_f1 = '1' else '0';
syl_edge <= '1' when syl_f2 = '0' and syl_f1 = '1' else '0';


proc: process (clk, rst_n) is
begin  -- process proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    line_counter <= 0;
    col_counter <= 0;    
  elsif clk'event and clk = '1' then    -- rising clock edge
    if sens_syt = '1' then
      line_counter <= 0;
      col_counter <= 0;
      pxl_aux <= (others => '0');
    elsif syl_edge = '1' then
      line_counter <= line_counter + 1;
      col_counter <= 0;
      pxl_aux <= (others => '0');
    elsif syp_edge = '1' then
      col_counter <= col_counter + 1;
      pxl_aux <= std_logic_vector(unsigned(pxl_aux) + 1);
    else
      col_counter <= col_counter;
      line_counter <= line_counter;
      pxl_aux <= pxl_aux;
    end if;
  end if;
end process proc;
  
--pxl_out <= std_logic_vector(to_unsigned(col_counter, pxl_out'length));
pxl_out <= std_logic_vector(frame_counter);

end architecture bhv;
