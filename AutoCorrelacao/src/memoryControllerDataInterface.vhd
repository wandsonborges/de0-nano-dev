-------------------------------------------------------------------------------
--! file memoryControllerDataInterface.vhd
--! @author wandson@ivision.ind.br
--! @brief Memory Controller Data Interface
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Description: It converts the autocorrelation result saved in buffer to a
-- byte stream
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2016-02-24  1.0      wandson	Created
-------------------------------------------------------------------------------


library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;


-------------------------------------------------------------------------------
--! @brief It converts the autocorrelation result saved in buffer to a
--! byte stream
-------------------------------------------------------------------------------
entity memoryControllerDataInterface is
	
	generic (
		W : positive := ConstDefaultTimeWindow;  --! Time window
                BITS_TO_COMPLETE : integer := (N_BITS_ACC_OUTPUT_TOTAL mod 8);
                NUM_OF_BYTES : integer := N_BITS_ACC_OUTPUT_TOTAL/8
                );

	port (
		clk : in std_logic;
		nrst : in std_logic;
		Cj : in std_logic_vector(N_BITS_ACC_OUTPUT_TOTAL-1 downto 0);  		--! The autocorrelation result input data for a given j
		byteSelector : in integer; 												--! From the Cj data input, it selects which byte is output to the v200's memory controller
		dataOut: out std_logic_vector(7 downto 0) 								--! Byte output to v200's memory controller
		);
end entity memoryControllerDataInterface;

architecture memoryControllerDataInterface1 of memoryControllerDataInterface is

 type t_CjVector is array(0 to NUM_OF_BYTES) of std_logic_vector(7 downto 0);
      signal CjVector : t_CjVector  := (others => (others => '0')); 
  
begin  -- architecture memoryControllerDataInterface1

--! @brief it selects byte of Cj (result of autocorrelation) to be streamed to
--! the external v200's memory controller
proc: process (Cj) is
begin  -- process proc       
           for i in 0 to NUM_OF_BYTES-1 loop
             CjVector(i) <= Cj(8*i + 7 downto 8*i);
           end loop;
           if BITS_TO_COMPLETE /= 0 then
             CjVector(NUM_OF_BYTES)(BITS_TO_COMPLETE-1 downto 0) <= Cj(N_BITS_ACC_OUTPUT_TOTAL-1 downto N_BITS_ACC_OUTPUT_TOTAL-1 - BITS_TO_COMPLETE);
           else
             CjVector(NUM_OF_BYTES) <= Cj(N_BITS_ACC_OUTPUT_TOTAL-1 downto N_BITS_ACC_OUTPUT_TOTAL-1 - 7);
           end if;

end process proc;

dataOut <= x"d5"; --CjVector(3-byteSelector);

end architecture memoryControllerDataInterface1;
