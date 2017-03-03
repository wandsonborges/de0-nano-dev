-------------------------------------------------------------------------------
--! @file dataInterface.vhd
--! @author wandson@ivision.ind.br
--! @brief Data Interface to the user module, through which it can retrieve the autocorrelation result
--! @image html doc/ac_data_path.png
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

LIBRARY altera_mf;
USE altera_mf.all;


-------------------------------------------------------------------------------
--! @brief It implements the Data Interface block depicted in the image.
--!
--! @image html doc/ac-data-path.png
--!
--! It reads the 32bits word autocorrelation data from the
--! autocorrelation buffer and buffers it into the internal FIFO;
--! The data is read by the user module in a 16bit words stream.
-------------------------------------------------------------------------------

entity dataInterface is
	
	generic (
		W : positive := ConstDefaultTimeWindow;  --! Time window
		N_BITS_TIME_WINDOW 	: natural 			:= ConstDefaultNbitsTimeWindow
		);

	port (
		clk 				: in std_logic;
		nrst 				: in std_logic;

		--Signals coming from autocorrelation buffer
		Cj 					: in std_logic_vector(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0);  		--! The autocorrelation result input data for a given j

		--Signals coming from the control unit
		jIndex 				: in std_logic_vector(N_BITS_TIME_WINDOW downto 0); 				--! The index that indexes the autocorrelation buffer		
		autocorrelationBusy : in std_logic; 													--! Control unit busy if '1'		

		--Signals coming from user module that reads the autocorrelation data
		clkRead 			: in std_logic; 						--! The read clock		
		readCjBuffer 		: in std_logic; 						--! The rising edge signals the start of a read transfer		
		read 				: in std_logic; 						--! For every cycle it is asserted as '1', it reads an autocorrelation 16bits word		


		--Signals to the control unit
		clear_jIndex 		: out std_logic; 						--! '1': it clears jIndex; '0': no effect		
		load_jIndex 		: out std_logic; 						--! '1': it increments jIndex; '0': no effect		
		dec_jIndex 			: out std_logic; 						--! '1': it decrements jIndex; '0': no effect		
		busy 				: out std_logic; 						--! '1': Data is being read by user module		

		--Signals to the user module that reads data
		CjDataAvailable 	: out std_logic; 						--! After user module pulses readCjBuffer, it must wait for thisa signal to be set to '1', indicating there is data available in the internal buffer to be read		
		dataOut 			: out std_logic_vector(15 downto 0) 	--! Autocorrelation result data output upon read request
		);
end entity dataInterface;

architecture dataInterface1 of dataInterface is

	type TypeState is (StateInit, 					--It waits for user module to assert the start of a read transfer

					   StateFirstFeed, 				--It resets the autocorrelation buffer iterator jIndex

					   StateWaitCjBufferLatency, 	--It waits for autocorrelation buffer's latency in order ot start reading form it

					   StateInsertMsw, 				--The 2 most significant bytes of the next 32bits word read from the autocorrelation buffer is written into the FIFO
					   
					   StateInsertLsw, 				--The 2 least significant bytes of the next 32bits word read from the autocorrelation buffer is written into the FIFO

					   StateWaitForFifo, 			--Should the FIFO become full, it waits for room to be made available

					   StateInsertFirstMsw, 		--The 2 most significant bytes of the first 32bits word read from the autocorrelation buffer is written into the FIFO

					   StateInsertFirstLsw 			--The 2 least significant bytes of the first 32bits word read from the autocorrelation buffer is written into the FIFO
					   );

	signal state 				: TypeState;
	signal insert 				: std_logic;
	signal resetFifo 			: std_logic;
	signal full 				: std_logic;
	signal nearFull				: std_logic;
	signal readCjBufferStage1 	: std_logic;
	signal readCjBufferStage2 	: std_logic;
	signal readCjBufferStage3 	: std_logic;
	signal readCjBufferPulse 	: std_logic;
	signal dataToInsert 		: std_logic_vector(15 downto 0);
	signal localDataOut 		: std_logic_vector(15 downto 0);
	signal latencyCounter 		: natural;
	signal resetIndeed          : std_logic;
  
begin  -- architecture memoryControllerDataInterface1

	insert <= '1' when (state = StateInsertFirstLsw) else
			  '1' when (state = StateInsertFirstMsw) else
			  '1' when (full = '0' and state = StateInsertLsw) else
			  '1' when (full = '0' and state = StateInsertMsw) else
			  '0';



    -- A dual clock FIFO to buffer data read from the autocorrelation buffer in
	-- in the autocorrelation's clock domain; the data is read from this FIFO
	-- in the user module's clock domain
	FifoDualClk4x16_1: entity work.FifoDualClk4x16
		port map (
			ClkInsert	=> clk,
			ClkRemove	=> clkRead,
			Insert		=> insert,
			Remove		=> read,
			Reset		=> resetIndeed,
			DataInsert	=> dataToInsert,
			RemovedData => localDataOut,
			probe		=> open,
			nearFull 	=> nearFull,
			Full		=> full);

	dataOut <= localDataOut; 


	resetIndeed <= resetFifo and not readCjBufferPulse;
	readCjBufferPulse <= readCjBufferStage2 and not readCjBufferStage3;

	--!@brief It reads the 32bits word autocorrelation data from the
	--! autocorrelation buffer and buffers it into the internal FIFO
	procFeedBuffer: process (clk, nrst) is
	begin  -- process procFeedBuffer
		if (nrst = '0') then
			clear_jIndex <= '1';
			resetFifo <= '0';
			busy <= '0';
			CjDataAvailable <= '0';
			latencyCounter <= 0;
			readCjBufferStage1 <= '0';
			readCjBufferStage2 <= '0';
			readCjBufferStage3 <= '0';                        
			state <= StateInit;
		elsif (clk'event and clk = '1') then
			
			--Clock decoupling
			readCjBufferStage1 <= readCjBuffer;
			readCjBufferStage2 <= readCjBufferStage1;
			readCjBufferStage3 <= readCjBufferStage2;
			
			case state is
				--It waits for user module to assert the start of a read transfer
				when StateInit =>
					clear_jIndex <= '1';
					resetFifo <= '0';
					CjDataAvailable <= '0';
					latencyCounter <= 0;
					busy <= '0';
					if (readCjBufferStage2 = '1') then
						resetFifo <= '1';
						busy <= '1';
						state <= StateFirstFeed;
					end if;

				--It resets the autocorrelation buffer iterator jIndex
				when StateFirstFeed =>
					clear_jIndex <= '0';
					state <= StateWaitCjBufferLatency;

				--It waits for autocorrelation buffer's latency in order ot
				--start reading form it
				when StateWaitCjBufferLatency =>
					if (latencyCounter = 1)  then
						latencyCounter <= 0;
						state <= StateInsertFirstLsw;
					else
						latencyCounter <= latencyCounter + 1;
					end if;

				--The 2 least significant bytes of the first 32bits word read
				--from the autocorrelation buffer is written into the FIFO
				when StateInsertFirstLsw =>
					state <= StateInsertFirstMsw;

				--The 2 most significant bytes of the first 32bits word read
				--from the autocorrelation buffer is written into the FIFO
				when StateInsertFirstMsw =>
					CjDataAvailable <= '1';
					if (jIndex = W-1) then
						state <= StateInit;
					else
						state <= StateInsertLsw;
					end if;
					if (readCjBufferPulse = '1') then
						state <= StateInit;
					end if;
					
				--The 2 least significant bytes of the next 32bits word read
				--from the autocorrelation buffer is written into the FIFO
				when StateInsertLsw =>
					if (full = '1') then
						state <= StateWaitForFifo;
					else
						state <= StateInsertMsw;
					end if;
					if (readCjBufferPulse = '1') then
						state <= StateInit;
					end if;

				--The 2 most significant bytes of the next 32bits word read
				--from the autocorrelation buffer is written into the FIFO
				when StateInsertMsw =>
					if (jIndex = W-1) then
						state <= StateInit;
					else
						state <= StateInsertLsw;
					end if;
					if (readCjBufferPulse = '1') then
						state <= StateInit;
					end if;

				--Should the FIFO become full, it waits for room to be made available
				when StateWaitForFifo =>
					if (full = '0') then
						state <= StateWaitCjBufferLatency;
					end if;
					if (readCjBufferPulse = '1') then
						state <= StateInit;
					end if;
					
				when others =>
					state <= StateInit;
			end case;
		end if;
	end process procFeedBuffer;

	dataToInsert <= Cj(23 downto 16) & Cj(31 downto 24) when (state = StateInsertFirstMsw or state = StateInsertMsw) else
					Cj(7 downto 0) & Cj(15 downto 8);


	------------------------------------------------
	--Driving outputs ------------------------------
	-----------------------------------------------
	
	load_jIndex <= '1' when (latencyCounter = 0 and state = StateWaitCjBufferLatency) else
				   '1' when (state = StateInsertFirstLsw) else
				   '1' when (full = '0' and state = StateInsertLsw) else
				   '0';

	dec_jIndex <= '1' when (full = '1' and state = StateInsertLsw) else '0'; --
	
end architecture dataInterface1;
