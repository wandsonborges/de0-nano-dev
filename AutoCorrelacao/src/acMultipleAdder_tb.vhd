-------------------------------------------------------------------------------
-- Title      : Testbench for design "acMultipleAdder"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : acMultipleAdder_tb.vhd
-- Author     : Wandson Borges  <wandson@wandson-laptop>
-- Company    : 
-- Created    : 2016-05-18
-- Last update: 2016-05-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2016-05-18  1.0      wandson	Created
-------------------------------------------------------------------------------

library ieee;
library work;
use ieee.std_logic_1164.all;
use work.lupa_library.all;

-------------------------------------------------------------------------------

entity acMultipleAdder_tb is

end entity acMultipleAdder_tb;

-------------------------------------------------------------------------------

architecture tb of acMultipleAdder_tb is

	-- component generics
	constant numberOfOperands	   : natural := 4;
	constant nbitsNumberOfOperands : natural := 2;

	-- component ports
	signal rst_n : std_logic := '0';
	signal dataIn	  : TypeArrayOfMultipleAdderOperands;
	signal result	  : std_logic_vector(N_BITS_MULTIPLE_ADDER_OPERAND-1 downto 0);

	-- clock
	signal Clk : std_logic := '0';

begin  -- architecture tb

  Clk <= not Clk after 10 ns;
  rst_n <= '1' after 100 ns;
	
	-- component instantiation
	DUT: entity work.acMultipleAdder
		generic map (
			numberOfOperands	  => 8,
			nbitsNumberOfOperands => 4,
			index => 0)
		port map (
			clk	   => clk,
			rst_n  => rst_n,
			dataIn => dataIn,
			result => result);

	-- clock generation
	Clk <= not Clk after 10 ns;

  dataIn(0) <= (0 => '1', others => '0');
  dataIn(1) <= (1 => '1', others => '0');
  dataIn(2) <= (2 => '1', others => '0');
  dataIn(3) <= (3 => '1', others => '0');
  dataIn(4) <= (4 => '1', others => '0');
  dataIn(5) <= (5 => '1', others => '0');
  dataIn(6) <= (6 => '1', others => '0');
  dataIn(7) <= (7 => '1', others => '0');
	-- waveform generation
	WaveGen_Proc: process
	begin
		-- insert signal assignments here
		
		wait until Clk = '1';
	end process WaveGen_Proc;

	

end architecture tb;

-------------------------------------------------------------------------------

configuration acMultipleAdder_tb_tb_cfg of acMultipleAdder_tb is
	for tb
	end for;
end acMultipleAdder_tb_tb_cfg;

-------------------------------------------------------------------------------
