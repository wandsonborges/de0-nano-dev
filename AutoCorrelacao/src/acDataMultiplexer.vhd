--! @file acDataMultiplexer.vhd
--! @author wandson@ivision.ind.br
--! @brief This module implements the Data MUX block depicted in the image below.
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


------------------------------------------------------------------------
--! @brief It implements the Data MUX block depicted in the image.
--!
--! @image html doc/ac-data-path.png
--!
--! This is the data mux of the output of the various sub-buffers of the
--! ac_frame_buffer module. It drives the operand 2 of the multiplier and
--! accumulator (MAC) units with the data output by one of the sub-buffers of
--! the frame buffer.
--!
--! The frame buffer data mux has as many mux as the number of parallel
--! autocorrelation processors; each mux drives the input of an
--! autocorrealation arithmetic unit;
--! Every mux is driven by all the sub-buffers of the framebuffer;
--! This control unit must also provide the selector of every mux in order
--! to select which sub-buffer will feed the input of the autocorrelation arithmetic
--! path (in this case, the multiplier and accumulator unit) corresponding
--! to the respective mux .
--!
--! There are a total of PARALLELISM_DEPTH sub-buffers in the frame
--! buffer and MAC units;
--! The value in sel(mac input i) selects the sub-buffer of the frame buffer,
--! ranging from 0 to PARALLELISM_DEPTH, that drives the input of the MAC unit i
--! A selection sel(mac input i) of value PARALLELISM_DEPTH or greater means
--! that the MAC unit i must  be disabled.
--------------------------------------------------------------------------

entity acDataMultiplexer is
  
  generic (
	PARALLELISM_DEPTH 	: natural 			:= ConstDefaultParallelismDepth
    );

  port (
    clk, rst_n         : in  std_logic;

    pxl_mean : in std_logic_vector(N_BITS_DATA + N_BITS_FRAC-1 downto 0);
    dataInA, dataInB 	  	 	      						: in TypeArrayOfOutputDataOfFrameBuffer;
    dataOutA, dataOutB   	 	      						: out TypeArrayOfOutputDataOfFrameBufferFrac;

	sel 										: in TypeArrayOfFrameBufferMuxSelect
	);
  

end entity acDataMultiplexer;

architecture bhv of acDataMultiplexer is

	constant N_BITS_PARALLELISM_DEPTH 		: integer := integer(ceil(log2(real(PARALLELISM_DEPTH))));

begin  -- architecture bhv


dataBuffers: for ii in 0 to PARALLELISM_DEPTH-1 generate	

procMux: process (clk, rst_n) is
begin  -- process procTimeWindowBuffer
	if (rst_n = '0') then
		dataOutA(ii) <= (others => '0');
		dataOutB(ii) <= (others => '0');
	elsif (clk'event and clk = '1') then
		if (to_integer(unsigned(sel(ii))) >= PARALLELISM_DEPTH) then
			-- There are o total of PARALLELISM_DEPTH sub-buffers in the frame
			-- buffer and MAC units;
			-- A selection sel(ii) of value PARALLELISM_DEPTH or greater means
			-- that the MAC unit ii must  be disabled;
			-- In order to accomplish that, the the input of the
			-- MAC unit ii is driven with the value pxl_mean, so that the
			-- result of the multiplication is zero
			dataOutB(ii) <= pxl_mean;
		elsif (to_integer(unsigned(sel(ii))) >= ii) then
			-- It selects the sub-buffer that drives dataInB that will drive
			-- the input of the MAC unit ii (dataOutB)
			dataOutB(ii) <= std_logic_vector(shift_left(resize(unsigned(dataInB(to_integer(unsigned(sel(ii))))), pxl_mean'length), N_BITS_FRAC));
		end if;
		--The input A of the MAC ii is always driven by data output by
		--sub-buffer ii
		dataOutA(ii) <= std_logic_vector(shift_left(resize(unsigned(dataInA(ii)), pxl_mean'length), N_BITS_FRAC));
	end if;
end process procMux;

end generate dataBuffers;             

end architecture bhv;
