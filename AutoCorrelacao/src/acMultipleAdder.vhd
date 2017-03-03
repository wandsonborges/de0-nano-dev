--! @file acMultipleAdder.vhd
--! @author wandson@ivision.ind.br
--! @brief Recursive adder
--! @image html doc/ac-data-path.png

library IEEE;
library work;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
use IEEE.math_real.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


--! @brief It implements the Multiple adder block depicted in the image.
--!
--! @image html doc/ac-data-path.png
--!
--! It adds the results of the many multipliers where there is parallelism;
--! It's performed as many sums as the number of multiplier and accumulator (MAC)
--! units, which is the value PARALLELISM_DEPTH

entity acMultipleAdder is
  
  generic (
	numberOfOperands 		: natural 			:= 2;
	index 				: natural
    );

  port (
    clk, rst_n         	: in  std_logic;

    dataIn				: in TypeArrayOfMultipleAdderOperands;
    result				: out std_logic_vector(N_BITS_MULTIPLE_ADDER_OPERAND-1 downto 0)
	);
  

end entity acMultipleAdder;

architecture bhv of acMultipleAdder is

	constant nbitsNumberOfOperands 		: integer := integer(ceil(log2(real(numberOfOperands))));

	signal resultA, resultB : std_logic_vector(N_BITS_MULTIPLE_ADDER_OPERAND-1 downto 0);

begin  -- architecture bhv

	recursiveAdder: if numberOfOperands >= 4 generate
		acMultipleAdder_1: entity work.acMultipleAdder
			generic map (
				numberOfOperands	  => numberOfOperands/2,
				index => index)
			port map (
				clk	   => clk,
				rst_n  => rst_n,
				dataIn => dataIn,
				result => resultA);

		acMultipleAdder_2: entity work.acMultipleAdder
			generic map (
				numberOfOperands	  => numberOfOperands/2,
				index => index + (numberOfOperands/2))
			port map (
				clk	   => clk,
				rst_n  => rst_n,
				dataIn => dataIn,
				result => resultB);

		procAdder: process (clk, rst_n) is
		begin  -- process procTimeWindowBuffer
			if (rst_n = '0') then
				result <= (others => '0');
			elsif (clk'event and clk = '1') then
				result <= std_logic_vector(signed(resultA) + signed(resultB));
			end if;
		end process procAdder;

	end generate recursiveAdder;
	

	finalAdder: if numberOfOperands = 2 generate
		procAdder: process (clk, rst_n) is
		begin  -- process procTimeWindowBuffer
			if (rst_n = '0') then
				result <= (others => '0');
			elsif (clk'event and clk = '1') then
				result <= std_logic_vector(signed(dataIn(index)) + signed(dataIn(index + 1)));
			end if;
		end process procAdder;
	end generate finalAdder;

	bypass: if numberOfOperands = 1 generate
		result <= dataIn(index);
	end generate bypass;



end architecture bhv;
