-------------------------------------------------------------------------------------
--! @file acControlUnit.vhd
--! @author wandson@ivision.ind.br
--! @brief Control unit of the Lupa's autocorrelation
-----------------------------------------------------------------------


library IEEE;
library work;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
use IEEE.math_real.all;


-----------------------------------------
--! @brief Control unit of the Lupa's autocorrelation
--!
--! It implements the Control Unit (UC) of the Autocorrelation's architecture
--!
--! Check out the diagram at ../../../Docs/Diagrams/control-unit.pdf
--!
--! The goal is to implement the equation, for every index of the image frame:
--!
--! C(j) = [ Sum{from i=0 to i=W-j}( p(i) - mean(p) )( p(i+j) - mean(p) ) ] / [ mean(p)^2 * (W-j) ]
--! 
--! Where:
--!
--! p(i) = value of pixel in instant in the past given by i
--! 
--! N = number of pixels in image frame
--!
--! W = number of frames in time window
--! 
--! mean(p) = mean of p over the time window
--!
--!
--! For future references:
--! 
--! C(j) = c(j) / [ mean(p)^2 * (W-j) ]
--! 
--! Where:
--! 
--! c(j) = [ Sum{from i=0 to i=W-j}( p(i) - mean(p) )( p(i+j) - mean(p) ) ] --
------------------------------------

entity acControlUnit is

	generic (
		mode 								: natural 	:= 1; 									--! Behaviour of this module: 0 - mode streaming - it continuouslly outputs autocorrelation; 1 - mode trigger - it triggers calculation of autocorrelation upon rise of signal vaiAutocorrelation
		spacialParallelismDepth 			: positive 	:= 1; 									--! Dn: number of units of autocorrelation temporally processing pixels in different indexes of the image frame
		temporalParallelismDepth_j 			: positive 	:= 1; 									--! Dj: number of units of autocorrelation processing pixels concurrently for different values of j, where j is a temporal index of the the autocorrelation
		PARALLELISM_DEPTH_OVER_i 			: natural 	:= ConstDefaultParallelismDepth; 		--! Di: number of units of autocorrelation processing pixels concurrently for different values of i, where i iterates the pixels temporally
		nStride 							: positive 	:= ConstDefaultFrameSize; 				--! this must equal N (number of pixels in frame) / Dn, which is the number of times the autocorrelation must be sequentially processed for every image frame
		jStride 							: positive 	:= ConstDefaultTimeWindow 				--! this must equal W (time window) / Dj, which is the number of times the autocorrelation must be sequentially processed over the iteration of j through the past
		);

	port (
		--! Inputs
		clk 									: in std_logic;	--! clock
		rst_n 									: in std_logic;	--! reset

		vaiAutocorrelation 			  			: in std_logic;	--! it fires autocorrelation		

		--! Signals from FrameBuffer
		frameBufferReady 						: in std_logic;	--! it flags '1' when FrameBuffer is configured and is loaded with the frames of the next time window
		timeWindowReady 						: in std_logic; --! it flags '1' when FrameBuffer has completed loading its buffer with the time window for current pixel index n from the external memory		

		--! Signals form the arithmetic unit
		temporalMeanCalculationDone 			: in std_logic;	--! it flags '1' when division unit is done calculating the temporal mean of the pixels
		squareOfTemporalMeanCalculationDone 	: in std_logic;	--! it flags '1' when autocorrelation unit is done calculating the square of the temporal mean of the pixels
		squareOfTemporalMeanTimesWDone 			: in std_logic; --! it flags '1' when arithmetic unit is done calculating the square of the temporal mean times W-j
		acSpacialMeanCalculationDone 			: in std_logic;	--! it flags '1' when the spacial mean of the autocorrelation is done calculating

		--! Signals from V200's memory controller
		memoryControllerBusy 					: in std_logic; --! it flags '1' when v200's memory controller is busy

		--! Signals to access the registers that hold i and j indexes, e.g. jDividerLatency
		clear_jDividerLatencyFromDataInterface 		: in std_logic; 	--! it clears jDividerLatency register		
		load_jDividerLatencyFromDataInterface		: in std_logic; 	--! it loads jDividerLatency register with next the next value		
		decrement_jDividerLatencyFromDataInterface 	: in std_logic; 	--! it decrements jDividerLatency register		

		--! Signals from data interface
		dataInterfaceBusy 							: in std_logic; --! it flags '1' when data Interface module is busy		

		--! Signals coming from module that writes data to the memory controller of the system
		dataBeingWrittenToExternalMemory 			: in std_logic; --! it flags '1' when there is data being written to external memory		
		

		--! Outputs

		--! Signals to the arithmetic unit
		startCalculatingTemporalMeanOfPixels 				: out std_logic; 						--! It signals division unit to start calculating the temporal mean of the pixels
		endCalculatingTemporalMeanOfPixels				: out std_logic; 							--! It tells division unit to end the accumulation of pixels for the calculation of the temporal mean
		setAccumulator 										: out std_logic_vector(temporalParallelismDepth_j-1 downto 0); --! it loads the accumulator the accumualtor with the first partial sum ( p(0) - mean(p) )( p(j) - mean(p) ) of the autocorrelation, so it restarts accumulating for the next i loop
		load_cj 											: out std_logic_vector(temporalParallelismDepth_j-1 downto 0); --! it loads the final result of the accumulation to register c_j, which holds c(j), according to equation
		decrementSquareOfTemporalMeanTimesWminus_j			: out std_logic_vector(temporalParallelismDepth_j-1 downto 0); --! it also decrements the the register that holds the multiplication <p>^2*(W-j) by <p>^2, so that the multiplication is updated with every increment of j
		accumulateCj 										: out std_logic_vector(temporalParallelismDepth_j-1 downto 0); --! it accumulates the final result of the autocorrelation c(j)/(mean(p)^2*(W-j)) into register Cj, which holds, according to the equation, C(j)
		setCj 												: out std_logic_vector(temporalParallelismDepth_j-1 downto 0); --! it sets the final result of the autocorrelation c(j)/(mean(p)^2*(W-j)) for the first frame index into register Cj, which holds, according to the equation, C(j)

		--! Signals to the FrameBuffer
		getNextSetOfFrames 									: out std_logic; 	--!It tells the FrameBuffer to update its content with the next set of frames to calculate the autocorrelation
		getNextTimeWindow 									: out std_logic; 	--!It tells the FrameBuffer to update its buffer with the time window for the current pixel index n

		--! Signals to the module that writes data to the external memory
		enableSensorDataToExternalMemory 					: out std_logic; 	--! when '1', it enables the module that writes data to the external memory to write the data that will be the input of the autocorrelation process

		--! Status
		busy 												: out std_logic;

		--! Signals output to the ac frame buffer module, the module that buffers the input data of the autocorrelation from the external memory
		acFrameBufferReadAddressA							: out TypeArrayOfReadAdressesOfFrameBuffer;	 --! read address of the of the A memory bus
		acFrameBufferReadAddressB							: out TypeArrayOfReadAdressesOfFrameBuffer;	 --! read address of the of the A memory bus

		--! Signals output to the module that multiplex the data ouput by the frame buffer
		selAcFrameBufferDataMux 							: out TypeArrayOfFrameBufferMuxSelect;		 --! it selects which of the sub-buffers into which the frame buffer is split for parallelism sake drives the data to be processed by the autocorrelation data path

		enableMac 											: out std_logic_vector(PARALLELISM_DEPTH_OVER_i-1 downto 0);

		--! Indexes and iterators
		n 													: out TypeArrayOfSpacialIndexes; --! spacial index of image frame; there are Dn indexes n, one for every autocorrelation unit that processes concurrently for different indexes in image frame
		j 													: out TypeArrayOfTemporalIndexes; --! temporal index j; there are Dj indexes j, one for every autocorrelation unit that processes concurrently for different values of j
		i 													: out TypeArrayOfTemporalIndexes; --! temporal index i; there are Di indexes i, one for every autocorrelation unit that processes concurrently for different values of i
		jCjBuffer											: out TypeArrayOfTemporalIndexes --! delayed temporal index j; this index j is synchronized with the output of the division unit; therefore, it must be used as the j index of the Cj buffer
		);
end entity acControlUnit;


-----------------------------
--! \brief Immplementation of the control unit
--------------------------------------------
architecture acControlUnit1 of acControlUnit is

	--! the number of times the autocorrelation must be sequentially processed in the iteration of i through the
	--! past, given the processing parallelism;
	--! in other words, i must only iterate up to the iStride value, as there is
	--! PARALLELISM_DEPTH_OVER_i parallel processors processing
	--!	simultaneously PARALLELISM_DEPTH_OVER_i chunks of all
	--!	possible values of i from 0 to W-1
	--! That means iStride is the size of the sub-buffers of the frame buffer
	constant iStride 								: natural := W / PARALLELISM_DEPTH_OVER_i;
	constant N_BITS_PARALLELISM_DEPTH_OVER_i 		: integer := integer(ceil(log2(real(PARALLELISM_DEPTH_OVER_i))));
	constant ConstPipelineDepthWithMultipleAdder 	: natural := ConstPipelineDepth + N_BITS_PARALLELISM_DEPTH_OVER_i; 		--! pipeline considering the inclusion of the multiple adder module for parallel processing		
	
	--! States of procAC
	type typeState is (
		StateInit,							
		
		StateDisableDataWriteToExternalMemory,		--! it disables any write access
													--! to the external memory
		
		StateUpdateFrameBuffer,						--! Between the calculation of
													--! the autocorrelation
													--! for every index of the frame, it
													--! updates the FrameBuffer with
													--! the next set of
													--! frames to work with

		StateWaitForFrameBuffer, 					--! It waits for frame buffer
													--! to be up to date

		StateLoopOverTheFrame,						--! The autocorrelation
													--! is performed for
													--! every index of
													--! the image frame;
													--! it also
													--! requests the frame buffer to
													--! start loading its buffer with
													--! time window of the current
													--! index of the image frame
					   
		StateWaitToStartTimeWindowRetrieval,	 	--! It waits until frame
													--! buffer has started
													--! getting time window of
													--! the current index of image frame

		StateWaitForFrameBufferToLoadTimeWindow, 	--! It waits until frame
													--! buffer has loaded its
													--! buffer with the time window of
													--! the current index of image frame

		StateWaitForAcFrameBufferLattency,			--! It waits for until the data 
													--! addressed by iLocal at the 
													--! ac_frame_buffer to be available 
													--! at its output

		StateCalculateTemporalMeanOfPixels,			--! It commands the division
													--! unit to accumulate the pixels
													--! for the calculation of their 
													--! temporal mean
					   
		StateEndCalculatingTemporalMeanOfPixels,	--! It commands the division
													--! unit to keep the accumulated
													--! value and perform the 
													--! mean related division

		StateWaitForLoopOverPastToStart,		--! Wait for all processes
												--! procLoopOverThePast_jj,
												--! which loops over the past,
												--! to start 
		
		StateFeedAcPipeline,					--! Iterators i and j
												--! start looping over the time
												--! window, feeding the
												--! pipeline of the
												--! core of the autocorrelation
												--! unit with the
												--! first past values
												--! of pixels; The time
												--! to wait is the pipeline depth
												--! +1 (which is the time the frame buffer takes
												--! to output the pixels addressed by i and i+j)
		
		StateLoopOverThePast					--! It waits for the processes
												--! procLoopOverThePast_jj to
												--! finish execution

		);		

	
	--! States of machine procLoopOverThePast
	type TypeStateLoopOverThePast is (
		StateInit,
		
		StateFeedAcPipeline,					--! It waits for the delay of
												--! the core of the autocorrelation's pipeline to
												--! start iterating jLatency and
												--! iLatency, which will provide
												--! the time reference to grab
												--! the final result of the
												--! accumulation and reset
												--! the it before it starts
												--! accumulating again for the
												--! next i loop
		
		StateLoopOverThePast,					--! i and j loop over the
												--! past, calculating
												--! the autocoorelation
												--! for every
												--! temporal index j, until j equals W
		
		StateWaitForPipeline 					--! Wait until the partial result of
												--! the autocorrelation c(j) for the
												--! last index j is available at the
												--! output of the
												--! core of the autocorrelation's pipeline

		);


	type TypeArrayOfStateProcLoopOverThePast is array (0 to temporalParallelismDepth_j-1) of TypeStateLoopOverThePast;





	--! Bit vector versions
	signal nStrideBitVector: std_logic_vector(N_BITS_FRAME_SIZE downto 0);
	signal W_bitVector: std_logic_vector(N_BITS_TIME_WINDOW downto 0);
	
	--! These signals are the init value of n, j and i
	signal nInit: TypeArrayOfSpacialIndexes := (others => (others => '0'));
	signal jInit: TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal iInit: TypeArrayOfTemporalIndexes := (others => (others => '0'));

	signal nLocal 			: TypeArrayOfSpacialIndexes;					--! spacial index in image frame; there are Dn indexes n, one for every autocorrelation unit that processes concurrently for different indexes in image frame
	signal jLocal 			: TypeArrayOfTemporalIndexes := (others => (others => '0')); 					--! temporal index j; there are Dj indexes j, one for every autocorrelation unit that processes concurrently for different values of j
	signal iLocal 			: TypeArrayOfTemporalIndexes := (others => (others => '0')); 					--! temporal index i; there are Dj indexes i, one for every autocorrelation unit that processes concurrently for different values of j

	--! The values of i and j for the next clock cycle
	signal next_i: 						TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_j: 						TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_iProcAc: 				TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_iProcLoopOverThePast: 	TypeArrayOfTemporalIndexes := (others => (others => '0'));

	--! The values of i and j L cycles in the past, where L is the
	--! latency of the autocorrelation's arithmetic unit
	signal jLatency: TypeArrayOfTemporalIndexes := (others => (others => '0')); 					
	signal iLatency: TypeArrayOfTemporalIndexes := (others => (others => '0'));

	--! The values of iLatency and jLatency Ld cycles in the past, where Ld is the
	--! latency of the division c(j) / [ mean(p)^2 * (W-j) ]
	signal jDividerLatency: TypeArrayOfTemporalIndexes := (others => (others => '0')); 					
	signal iDividerLatency: TypeArrayOfTemporalIndexes := (others => (others => '0'));

	--! The values of i and j for the next clock cycle L cycles in the past, where L is the
	--! latency of the autocorrelation's arithmetic unit
	signal next_iLatency: TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_jLatency: TypeArrayOfTemporalIndexes := (others => (others => '0'));

	--! The values of iLatency and jLatency for the next clock cycle Ld cycles in the past, where Ld is the
	--! latency of the division c(j) / [ mean(p)^2 * (W-j) ]
	signal next_iDividerLatency: 					TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_jDividerLatency: 					TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_jDividerLatencyProcLoopOverThePast: TypeArrayOfTemporalIndexes := (others => (others => '0'));
	signal next_jDividerLatencyProcDataInterface: 	TypeArrayOfTemporalIndexes := (others => (others => '0'));

	--! Signals that are arithmetic operation on W
	signal Wminus1 							: std_logic_vector(N_BITS_TIME_WINDOW downto 0);	--!W-1
	signal Wminus1minusj 					: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-j
	signal Wminus1minus_jLatency 			: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-jLatency
	signal Wminus1minus_jDividerLatency 	: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-jDividerLatency
	signal end_of_i_loop 					: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-j
	signal end_of_iLatency_loop 			: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-j
	signal end_of_iDividerLatency_loop		: TypeArrayOfTemporalIndexes := (others => (others => '0'));	--!(W-1)-j

	--! States of state machines
	signal state: 						TypeState := StateInit;
	signal stateProcLoopOverThePast: 	TypeArrayOfStateProcLoopOverThePast;

	--! Counters
	signal pipelineCount, dividerPipelineCount 	: natural;
	signal acByteCounter 						: natural;


	--! Communication between state machines
	signal loopOverPast: 					std_logic;
	signal anyLooping: 						std_logic;
	signal looping: 						std_logic_vector(temporalParallelismDepth_j-1 downto 0);

	--! i and j drivers
	signal load_i_procAC, load_i_procLoopOverThePast: 	std_logic_vector(temporalParallelismDepth_j-1 downto 0);
	signal clear_i_procLoopOverThePast:					std_logic_vector(temporalParallelismDepth_j-1 downto 0);
	signal clear_i_procAC: 								std_logic;

	--! jDividerLatency drivers
	signal load_jDividerLatency_procLoopOverThePast: 	std_logic_vector(temporalParallelismDepth_j-1 downto 0);
	signal clear_jDividerLatency_procLoopOverThePast:	std_logic_vector(temporalParallelismDepth_j-1 downto 0);

	--! signals that are arithmetic operations on iterators i and j
	signal i_plus_j_local 					: std_logic_vector(N_BITS_TIME_WINDOW+1 downto 0);
	signal iLatency_plus_jLatency			: std_logic_vector(N_BITS_TIME_WINDOW+1 downto 0);
	signal j_divided_by_i_stride 			: std_logic_vector(N_BITS_PARALLELISM_DEPTH_OVER_i downto 0);
	signal i_plus_j_divided_by_i_stride 	: std_logic_vector(N_BITS_PARALLELISM_DEPTH_OVER_i downto 0);

	--! Locals
	signal load_cjLocal: 	std_logic_vector(temporalParallelismDepth_j-1 downto 0);
	signal numberOfSaves, timer : natural;

	--! clock buffers
	signal vaiAutocorrelationStage1, vaiAutocorrelationStage2 								: std_logic;
	signal dataBeingWrittenToExternalMemoryStage1, dataBeingWrittenToExternalMemoryStage2 	: std_logic;

	--! frame buffer multiplexer selectors
	signal selAcFrameBufferDataMuxPartialSum 	: TypeArrayOfNbitsParallelismDepthPlus1;
	signal selAcFrameBufferDataMuxStage1 		: TypeArrayOfNbitsParallelismDepthPlus1;
	signal selAcFrameBufferDataMuxStage2 		: TypeArrayOfFrameBufferMuxSelect;



begin
  
	nStrideBitVector <= std_logic_vector(to_unsigned(nStride, N_BITS_FRAME_SIZE+1));
	W_bitVector <= std_logic_vector(to_unsigned(W, N_BITS_TIME_WINDOW+1));
	
	------------------------------------------------------------------
	--! \brief purpose: it resets indexes
	--!
	--! The init value for the indexes n of the image frame n are equally
	--! spaced by nStride; every autocorrelation unit which processes pixels in
	--! different indexes of the image frame concurrently processes the pixels
	--! given by the indexes: n = nd * N / Dn, where:
	--! N is the number of pixels in the image frame
	--! Dn is the number of autocorrelation units processing different indexes
	--! of the frame concurrently
	--! nd ranges from 0 through Dn-1
	--!
	--! The init value of iterator j is the index jj, which identifies one
	--! autorocorrelation unit that operates concurrently on j;
	--! For the autocorrelation unit jj, the
	--! sequential value of j is jj, jj + temporalParallelismDepth_j, jj +
	--! temporalParallelismDepth_j*2, jj + temporalParallelismDepth_j*3, ...,
	--! jj  + (W - temporalParallelismDepth_j)
	reset_indexes: process (nInit, nStrideBitVector) is
	begin  -- process reset_indexes
		
		-- The init value for the indexes n of the image frame n are equally
		-- spaced by nStride; every autocorrelation unit which processes pixels in
		-- different indexes of the image frame concurrently processes the pixels
		-- given by the indexes: n = nd * N / Dn, where:
		-- N is the number of pixels in the image frame
		-- Dn is the number of autocorrelation units processing different indexes
		-- of the frame concurrently
		-- nd ranges from 0 through Dn-1
		nInit(0) <= (others => '0');
		for ni in 1 to spacialParallelismDepth-1 loop
			nInit(ni) <= nInit(ni-1) + nStrideBitVector;
		end loop;

		-- The init value of iterator j is the index jj, which identifies one
		-- autorocorrelation unit that operates concurrently on j;
		-- For the autocorrelation unit jj, the
		-- sequential value of j is jj, jj + temporalParallelismDepth_j, jj +
		-- temporalParallelismDepth_j*2, jj + temporalParallelismDepth_j*3, ..., jj
		-- + (W - temporalParallelismDepth_j)
		for jj in 0 to temporalParallelismDepth_j-1 loop
			jInit(jj) <= std_logic_vector(to_unsigned(jj, N_BITS_TIME_WINDOW+1));
		end loop;
	end process reset_indexes;


	--------------------------------------------------------------------
	--! \brief purpose: it calculates (W-1)-j for j in the present and in the
	--! past L cycles later (jLatency), where L is the autocorrelation's latency;
	--! It also calculates the last value to which iterators i and iLatency
	--! must iterate (end_of_i_loop); they depend on the presence of parallel processing (PARALLELISM_DEPTH_OVER_i > 1)
	------------------------------------------------------------------------
	procCalculateWminus1minus_j: process (W_bitVector, jLocal, jLatency, jDividerLatency,
										  Wminus1minusj, Wminus1minus_jLatency, Wminus1minus_jDividerLatency) is
	begin  -- process procCalculateWminus1minus
		for jj in 0 to temporalParallelismDepth_j-1 loop
			--!it calculates Wminus1minusj
			Wminus1minusj(jj) <= (W_bitVector-1) - jLocal(jj);
			Wminus1minus_jLatency(jj) <= (W_bitVector-1) - jLatency(jj);
			Wminus1minus_jDividerLatency(jj) <= (W_bitVector-1) - jDividerLatency(jj);

			if (PARALLELISM_DEPTH_OVER_i = 1) then
				end_of_i_loop(jj) <= Wminus1minusj(jj);
			elsif (jLocal(jj)((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)) = (PARALLELISM_DEPTH_OVER_i-1) ) then
				--!Here,( W-j ) is smaller than the iStride; therefore, i must
				--!not iterate up to the iStride value
				end_of_i_loop(jj) <= Wminus1minusj(jj);
			else
				--! i must only iterate up to the iStride value, as there is
				--! PARALLELISM_DEPTH_OVER_i parallel processors processing
				--!simultaneously PARALLELISM_DEPTH_OVER_i chunks of all
				--!possible values of i from 0 to W-1  
				end_of_i_loop(jj) <= std_logic_vector(to_unsigned(iStride - 1, end_of_i_loop(jj)'length));
			end if;	

			--! Calculation of last value of i L cyccles in the past (iLatency)
			if (PARALLELISM_DEPTH_OVER_i = 1) then
				end_of_iLatency_loop(jj) <= Wminus1minus_jLatency(jj);
			elsif (jLatency(jj)((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)) = (PARALLELISM_DEPTH_OVER_i-1) ) then
				end_of_iLatency_loop(jj) <= Wminus1minus_jLatency(jj);
			else
				end_of_iLatency_loop(jj) <= std_logic_vector(to_unsigned(iStride - 1, end_of_iLatency_loop(jj)'length));
			end if;	

			if (PARALLELISM_DEPTH_OVER_i = 1) then
				end_of_iDividerLatency_loop(jj) <= Wminus1minus_jDividerLatency(jj);
			elsif (jDividerLatency(jj)((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)) = (PARALLELISM_DEPTH_OVER_i-1) ) then
				end_of_iDividerLatency_loop(jj) <= Wminus1minus_jDividerLatency(jj);
			else
				end_of_iDividerLatency_loop(jj) <= std_logic_vector(to_unsigned(iStride - 1, end_of_iDividerLatency_loop(jj)'length));
			end if;	
		end loop;
	end process procCalculateWminus1minus_j;



	-------------------------------------------------------------------
	--! \brief It defines the value of the indexes i and j for the next clock cycle
	--!
	--! For the states StateFeedAcPipeline and StateLoopOverThePast,
	--! it defines the value of the iterators i and j for the next clock cycle;
	--! When i finishes looping over the past (i = W-j), i resets to 0 and j
	--! is incremented by temporalParallelismDepth_j ; else, i is incremented and j goes unchanged
	--!
	--! For the state StateCalculateTemporalMeanOfPixels,
	--! it defines the value of the iterator i as its increment
	--!
	--! For the autocorrelation unit jj that operates concurrently on j, the
	--! sequential value of j is jj, jj + temporalParallelismDepth_j, jj +
	--! temporalParallelismDepth_j*2, jj + temporalParallelismDepth_j*3, ...,
	--! jj  + (W - temporalParallelismDepth_j)
	----------------------------------------------------------------------------
	next_iterators_assignment: process (W_bitVector, iLocal, jLocal, state,
										next_iProcAc, next_iProcLoopOverThePast, end_of_i_loop) is
	begin  -- process next_iterators_assignment
		for jj in 0 to temporalParallelismDepth_j-1 loop

			next_iProcAc(jj) <= iLocal(jj) + 1;

			if (jLocal(jj) = W_bitVector) then
				next_iProcLoopOverThePast(jj) <= (others => '0');
				next_j(jj) <= W_bitVector;
			elsif (iLocal(jj) = end_of_i_loop(jj)) then
				next_iProcLoopOverThePast(jj) <= (others => '0');
				next_j(jj) <= jLocal(jj) + temporalParallelismDepth_j;
			else
				next_iProcLoopOverThePast(jj) <= iLocal(jj) + 1;
				next_j(jj) <= jLocal(jj);
			end if;
				
			if ((state = StateCalculateTemporalMeanOfPixels) or (state = StateWaitForAcFrameBufferLattency)) then
				next_i(jj) <= next_iProcAc(jj);
			else
				next_i(jj) <= next_iProcLoopOverThePast(jj);
			end if;
		end loop;
	end process next_iterators_assignment;
	

	generate_i_registers:
	for jj in 0 to temporalParallelismDepth_j-1 generate

		------------------------------------------------------------------------
		--! @brief purpose: these are the registers that keep the value of
		--! temporal iterator i for every parallel core of the autocorrelation
		--! processing concurrently for different values of j
		---------------------------------------------------------------------
		i_register_jj: process (clk, rst_n) is
		begin  -- process
			if (rst_n = '0') then
				iLocal(jj) <= (others => '0');
			elsif (clk'event and clk = '1') then
				if ((state = StateCalculateTemporalMeanOfPixels) or (state = StateWaitForAcFrameBufferLattency)) then
					-- iLocal is incremented during calculation of temporal mean
					-- of pixels in order to address the frame buffer and retrive
					-- the values of pixels
					if (load_i_procAC(jj) = '1') then
						iLocal(jj) <= next_i(jj);
					elsif (clear_i_procAC = '1') then
						iLocal(jj) <= (others => '0');
					else
						iLocal(jj) <= iLocal(jj);
					end if;
				else
					-- i and j keep feeding pixels into the input of the
					-- core of the autocorrelation when this control unit
					-- loops over the past to calculate the autocorrelation
					if (load_i_procLoopOverThePast(jj) = '1') then
						iLocal(jj) <= next_i(jj);
					elsif (clear_i_procLoopOverThePast(jj) = '1') then
						iLocal(jj) <= (others => '0');
					else
						iLocal(jj) <= iLocal(jj);
					end if;
				end if;
			end if;
		end process i_register_jj; 
		
	end generate generate_i_registers;
	
	

	---------------------------------------------------------------------------
	--! @brief It defines the value of the delayed iterators iLatency and jLatency for the next clock cycle
	--!
	--! These are the i and j iterators delayed by the autocorrelation unit's pipeline
	--!
	--! This way, this control unit can know when the result of autocorrelation
	--! is ready in the accumulator
	--!
	--! When i finishes looping (iLatency = end_of_iLatency_loop), iLatency resets to 0 and jLatency
	--! is incremented; else, iLatency is incremented and jLatency goes unchanged
	----------------------------------------------------------------------------
	next_delayed_iterators_assignment: process (W_bitVector, iLatency, jLatency,
												end_of_iLatency_loop) is
	begin  -- process next_delayed_iterators_assignment
		for jj in 0 to temporalParallelismDepth_j-1 loop
			if (jLatency(jj) = W_bitVector) then
				next_iLatency(jj) <= (others => '0');
				next_jLatency(jj) <= W_bitVector;
			elsif (iLatency(jj) = end_of_iLatency_loop(jj)) then
				next_iLatency(jj) <= (others => '0');
				next_jLatency(jj) <= jLatency(jj) + temporalParallelismDepth_j;
			else
				next_iLatency(jj) <= iLatency(jj) + 1;
				next_jLatency(jj) <= jLatency(jj);
			end if;
		end loop;
	end process next_delayed_iterators_assignment;


	---------------------------------------------------------------------------
	--! @brief It defines the value of the delayed iterators iDividerLatency and jDividerLatency for the next clock cycle
	--!
	--! These are the iLatency and jLatency iterators delayed by the autocorrelation divider's pipeline
	--!
	--! This way, this control unit can know when the result of the division
	--c_j/(<p>^2 * (W-j)) is ready at the end of the divider's pipeline
	--!
	--! When i finishes looping (i = W-j), i resets to 0 and j
	--! is incremented; else, i is incremented and j goes unchanged
	------------------------------------------------------------------------------
	next_delayed_by_divider_iterators_assignment: process (W_bitVector, end_of_iDividerLatency_loop,
														   iDividerLatency, jDividerLatency,
														   state, next_jDividerLatencyProcLoopOverThePast,
														   next_jDividerLatencyProcDataInterface) is
	begin  -- process next_delayed_by_divider_iterators_assignment
		for jj in 0 to temporalParallelismDepth_j-1 loop

			next_jDividerLatencyProcDataInterface(jj) <= jDividerLatency(jj) + 1;

			if (jDividerLatency(jj) = W_bitVector) then
				next_iDividerLatency(jj) <= (others => '0');
				next_jDividerLatencyProcLoopOverThePast(jj) <= W_bitVector;
			elsif (iDividerLatency(jj) = end_of_iDividerLatency_loop(jj)) then
				next_iDividerLatency(jj) <= (others => '0');
				next_jDividerLatencyProcLoopOverThePast(jj) <= jDividerLatency(jj) + temporalParallelismDepth_j;
			else
				next_iDividerLatency(jj) <= iDividerLatency(jj) + 1;
				next_jDividerLatencyProcLoopOverThePast(jj) <= jDividerLatency(jj);
			end if;

			if (state = StateInit) then
				next_jDividerLatency(jj) <= next_jDividerLatencyProcDataInterface(jj);
			else
				next_jDividerLatency(jj) <= next_jDividerLatencyProcLoopOverThePast(jj);
			end if;
		end loop;
	end process next_delayed_by_divider_iterators_assignment;


	

	generate_jDividerLatency_registers:
	for jj in 0 to temporalParallelismDepth_j-1 generate

		--------------------------------------------------------------------------
		--! \brief purpose: these are the registers that keep the value of temporal iterator jDividerLatency for every parallel core of the autocorrelation processing concurrently for different values of j
		-----------------------------------------------------------------------------
		jDividerLatency_register_jj: process (clk, rst_n) is
		begin  -- process
			if (rst_n = '0') then
				jDividerLatency(jj) <= jInit(jj);
			elsif (clk'event and clk = '1') then
				if (state = StateInit) then
					-- jDividerLatency is incremented when this control unit is
					-- streaming the Cj buffer into the v200's memory
					-- controller, so that it iterates through the buffer
					if (load_jDividerLatencyFromDataInterface = '1') then
						jDividerLatency(jj) <= next_jDividerLatency(jj);
					elsif (decrement_jDividerLatencyFromDataInterface = '1') then
						jDividerLatency(jj) <= jDividerLatency(jj) - 1;
					elsif (clear_jDividerLatencyFromDataInterface = '1') then
						jDividerLatency(jj) <= jInit(jj);
					else
						jDividerLatency(jj) <= jDividerLatency(jj);
					end if;
				else
					-- when thos control unit is looping over the past to
					-- calculate the autocorrelation,
					-- iDividerLatency and jDividerLatency continuously registers the outputs
					-- of the division c(j)/<p>^2*(W-j) Ld
					-- cycles later (Ld = latency of the division unit)
					if (load_jDividerLatency_procLoopOverThePast(jj) = '1') then
						jDividerLatency(jj) <= jLatency(jj);
					elsif (clear_jDividerLatency_procLoopOverThePast(jj) = '1') then
						jDividerLatency(jj) <= jInit(jj);
					else
						jDividerLatency(jj) <= jDividerLatency(jj);
					end if;
				end if;
			end if;
		end process jDividerLatency_register_jj;
		
	end generate generate_jDividerLatency_registers;



	

	--------------------------------------------------------------
	--! @brief purpose: Main controller of the autocorrelation
	--!
	--! This process implements the state machine:
	--!
	--! \image html doc/control-unit-procAc.png
	--------------------------------------------------------------------------
	procAC: process (clk, rst_n, nInit, nLocal, looping, anyLooping, end_of_i_loop,
					 state, frameBufferReady, timer, dataBeingWrittenToExternalMemory,
					 pipelineCount, timeWindowReady, dataBeingWrittenToExternalMemoryStage1,
					 vaiAutocorrelation, vaiAutocorrelationStage1, vaiAutocorrelationStage2,
					 dataInterfaceBusy, numberOfSaves) is
	begin  -- process procAC

		-- anyLooping flags '1' if any of the processes procLoopOverThePast is
		-- running
		anyLooping <= looping(0);
		for jj in 1 to temporalParallelismDepth_j-1 loop
			anyLooping <= anyLooping or looping(jj);
		end loop;
		
		if rst_n = '0' then
			nLocal <= nInit;
			state <= StateInit;
			pipelineCount <= 0;
			dividerPipelineCount <= 0;
			clear_i_procAC <= '1';
			load_i_procAC(0) <= '0';
			busy <= '0';
			numberOfSaves <= 0;
			timer <= 0;
			vaiAutocorrelationStage1 <= '0';
			vaiAutocorrelationStage2 <= '0';
			getNextTimeWindow <= '0';
			enableSensorDataToExternalMemory <= '1';
		elsif (clk'event and clk = '1') then

			--clock buffers
			vaiAutocorrelationStage1 <= vaiAutocorrelation;
			vaiAutocorrelationStage2 <= vaiAutocorrelationStage1;

			dataBeingWrittenToExternalMemoryStage1 <= dataBeingWrittenToExternalMemory;
			dataBeingWrittenToExternalMemoryStage2 <= dataBeingWrittenToExternalMemoryStage1;
			
			case state is
				when StateInit =>
					getNextTimeWindow <= '0';
					clear_i_procAC <= '0';
					load_i_procAC(0) <= '0';
					enableSensorDataToExternalMemory <= '1';		 --when not busy, enables access to external memory
					if (mode /= 0) then
						--In trigger driven mode, it waits for signal
						if vaiAutocorrelationStage2 = '1' then
							busy <= '1';
							state <= StateDisableDataWriteToExternalMemory;
						end if;
					else
						state <= StateUpdateFrameBuffer;
					end if;
				when StateDisableDataWriteToExternalMemory =>
					--It disables write accesss to external memory and waits
					--for writing module to acknowledge it
					enableSensorDataToExternalMemory <= '0';
					if (dataBeingWrittenToExternalMemoryStage2 = '0') then
						state <= StateUpdateFrameBuffer;
					end if;
				when StateUpdateFrameBuffer =>
					-- It waits until the next set of frames is stored in frame
					-- buffer before start a new execution of the autocorrelation
					nLocal <= nInit;
					state <= StateWaitForFrameBuffer;
				when StateWaitForFrameBuffer =>
					-- It waits for frame buffer to be up to date
					if (frameBufferReady = '1') then
						state <= StateLoopOverTheFrame;
					end if;
				when StateLoopOverTheFrame =>
					-- The autocorrelation is performed for every index of the image frame
					-- It fires ac frame buffer to get the next time window
					-- from external memory when loop over every frame index is
					-- not finished
					if nLocal(0) = nStride then
						nLocal <= nInit;
						if (mode /= 0 ) then
							--Autocorrelation is finished when not in
							--continuous mode
							busy <= '0';
							state <= StateInit;
						else
							state <= StateUpdateFrameBuffer;
						end if;
					else
						clear_i_procAC <= '1';
						load_i_procAC(0) <= '0';
						getNextTimeWindow <= '1';
						state <= StateWaitToStartTimeWindowRetrieval;
					end if;
				when StateWaitToStartTimeWindowRetrieval =>
					--It waits for ac frame buffer to start retrieving the next time window
					getNextTimeWindow <= '0';
					if (timeWindowReady = '0') then
						state <= StateWaitForFrameBufferToLoadTimeWindow;
					end if;
				when StateWaitForFrameBufferToLoadTimeWindow =>
					--It waits for ac frame buffer to retrieve the next time window
					if (timeWindowReady = '1') then
						clear_i_procAC <= '0';
						load_i_procAC(0) <= '1';
						state <= StateWaitForAcFrameBufferLattency;
					end if;
				when StateWaitForAcFrameBufferLattency =>
					--It waits for data from frame buffer to go through the
					--frame buffer data path before fire calculation of
					--temporal mean
					if (to_integer(unsigned(iLocal(0))) = (FrameBufferLatency-2)) then
						state <= StateCalculateTemporalMeanOfPixels;
					end if;
				when StateCalculateTemporalMeanOfPixels =>
					--It calculates temporal mean of pixels
					if (unsigned(iLocal(0)) = (unsigned(end_of_i_loop(0)) + FrameBufferLatency)) then
						state <= StateEndCalculatingTemporalMeanOfPixels;
					end if;
				when StateEndCalculatingTemporalMeanOfPixels =>
					--It ends calculation of temporal mean
					clear_i_procAC <= '1';
					load_i_procAC(0) <= '0';
					loopOverPast <= '1';
					state <= StateWaitForLoopOverPastToStart;
				when StateWaitForLoopOverPastToStart =>
					-- Wait for all processes procLoopOverThePast_jj to start
                    clear_i_procAC <= '0';
					loopOverPast <= '0';
					if (anyLooping = '1') then
						state <= StateFeedAcPipeline;
					end if;
				when StateFeedAcPipeline =>
					-- Iterators i and j start looping over the time window, feeding the
					-- pipeline of the core of the autocorrelation with the first past values of pixels;
					-- This state counts the pipeline cycles 
					if (pipelineCount = ConstPipelineDepthWithMultipleAdder-1) then
						pipelineCount <= 0;
						state <= StateLoopOverThePast;
					else
						pipelineCount <= pipelineCount + 1;
						state <= StateFeedAcPipeline;
					end if;
				when StateLoopOverThePast =>
					-- It waits for all processes procLoopOverThePast_jj to
					-- finish execution
					if (anyLooping = '0') then
						state <= StateLoopOverTheFrame;

						for ni in 0 to spacialParallelismDepth-1 loop
							nLocal(ni) <= nLocal(ni) + 1;
						end loop;

						-- It clears iterator i before starting next calculation of
						-- temporal mean of pixels
						clear_i_procAC <= '1';
					end if;
				when others =>
					state <= StateInit;
			end case;

		end if;

	end process procAC;



	-- It creates as many processes as the number of units of autocorrelation processing pixels concurrently for different values of j
	generateProcessesThatLoopOverThePast:
	for jj in 0 to temporalParallelismDepth_j-1 generate

		---------------------------------------------------------------------------
		--! @brief purpose: For every unit of autocorrelation processing pixels concurrently for different values of j, it loops over the past
		--!
		--! This process implements the state machine:
		--!
		--! \image html doc/control-unit-procLoopOverThePast.png
		--
		-- inputs : clk, nrst
		-- outputs:  procLoopOverThePast
		--------------------------------------------------------------------------
		procLoopOverThePast_jj: process (clk, rst_n, stateProcLoopOverThePast, next_j,
										 next_jLatency, next_iLatency, loopOverPast,
										 pipelineCount,
										 jInit) is
		begin  -- process processecLoopOverThePast
			if (rst_n = '0') then
				load_i_procLoopOverThePast(jj) <= '0';
				clear_i_procLoopOverThePast(jj) <= '1';
				iLatency(jj) <= (others => '0');
				iDividerLatency(jj) <= (others => '0');
				jLocal(jj) <= jInit(jj);
				jLatency(jj) <= jInit(jj);
				load_jDividerLatency_procLoopOverThePast(jj) <= '0';
				clear_jDividerLatency_procLoopOverThePast(jj) <= '1';
				stateProcLoopOverThePast(jj) <= StateInit;
			elsif (clk'event and clk = '1') then
				case stateProcLoopOverThePast(jj) is
					when StateInit =>
						load_i_procLoopOverThePast(jj) <= '0';
						clear_i_procLoopOverThePast(jj) <= '1';
						iLatency(jj) <= (others => '0');
						iDividerLatency(jj) <= (others => '0');
						jLocal(jj) <= jInit(jj);
						jLatency(jj) <= jInit(jj);
						load_jDividerLatency_procLoopOverThePast(jj) <= '0';
						clear_jDividerLatency_procLoopOverThePast(jj) <= '1';
						if (loopOverPast = '1') then
							clear_i_procLoopOverThePast(jj) <= '0';
							load_i_procLoopOverThePast(jj) <= '1';
							clear_jDividerLatency_procLoopOverThePast(jj) <= '1';
							stateProcLoopOverThePast(jj) <= StateFeedAcPipeline;
						end if;
					when StateFeedAcPipeline =>
						-- i and j keeps feeding pixels into the input of the
						-- core of the autocorrelation 
						load_i_procLoopOverThePast(jj) <= '1';
						jLocal(jj) <= next_j(jj);

						-- It waits for the delay of the core of the autocorrelation's pipeline to
						-- start iterating jLatency and iLatency, which will provide
						-- the time reference to grab the final result of the
						-- accumulation and reset  the it before it starts
						-- accumulating again for the next i loop
						if (pipelineCount = ConstPipelineDepthWithMultipleAdder-1) then
							-- When pipeline time is up, iLatency must start
							-- iterating
							iLatency(jj) <= (others => '0');
							jLatency(jj) <= jInit(jj);
							stateProcLoopOverThePast(jj) <= StateLoopOverThePast;
						else
							stateProcLoopOverThePast(jj) <= StateFeedAcPipeline;
						end if;
					when StateLoopOverThePast =>
						-- i and j keeps feeding pixels into the input of the
						-- core of the autocorrelation during loop over past 
						load_i_procLoopOverThePast(jj) <= '1';
						jLocal(jj) <= next_j(jj);
						
						-- iLatency and jLatency continuously retrieves the output
						-- of the accumulation at the end of the i loop L
						-- cycles later (L = latency of the core of the autocorrelation)
						iLatency(jj) <= next_iLatency(jj);
						jLatency(jj) <= next_jLatency(jj);
						
						load_jDividerLatency_procLoopOverThePast(jj) <= '1';

						-- i and j loop over the past, calculating the autocoorelation
						-- for every temporal index j, until j equals W
						
						-- If next value of j is greater than the time window, it
						-- means the j iterations are done
						if (next_j(jj) >= std_logic_vector(to_unsigned(W, N_BITS_TIME_WINDOW+1))) then
							stateProcLoopOverThePast(jj) <= StateWaitForPipeline;
						end if;
					when StateWaitForPipeline =>
						load_i_procLoopOverThePast(jj) <= '0';
						
						-- iLatency and jLatency continuously retrieves the output
						-- of the accumulation at the end of the i loop L
						-- cycles later (L = latency of the core of the autocorrelation)
						iLatency(jj) <= next_iLatency(jj);
						jLatency(jj) <= next_jLatency(jj);
						
						load_jDividerLatency_procLoopOverThePast(jj) <= '1';

						-- Wait until the partial result of the autocorrelation c(j) for the
						-- last index j is available at the output of the
						-- core of the autocorrelation's pipeline
						if (next_jLatency(jj) >= std_logic_vector(to_unsigned(W, N_BITS_TIME_WINDOW+1))) then
							stateProcLoopOverThePast(jj) <= StateInit;
						end if;
					when others =>
						stateProcLoopOverThePast(jj) <= StateInit;
				end case;
			end if;

			--Status indicating when machine is operating
			if (stateProcLoopOverThePast(jj) /= StateInit) then
				looping(jj) <= '1';
			else
				looping(jj) <= '0';
			end if;

		end process procLoopOverThePast_jj;

	end generate generateProcessesThatLoopOverThePast;


	
	i_plus_j_local <= ("0" & iLocal(0)) + ("0" + jLocal(0));
	i_plus_j_divided_by_i_stride <= i_plus_j_local((N_BITS_TIME_WINDOW) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i));
	j_divided_by_i_stride <= jLocal(0)((N_BITS_TIME_WINDOW) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i));
	iLatency_plus_jLatency <= ("0" & iLatency(0)) + ("0" & jLatency(0));






	---------------------------------------------------------
	-------------- Driving outputs ---------------------------
	---------------------------------------------------------



	
	--------------------------------------------------------------
	--! @brief purpose: it generates the signals :
	--! - read address of frame buffer sub-buffers for both A and B bus interfaces
	--! - selector of the mux that is driven by data output from the sub-buffers
	--! 
	--! The frame buffer is split into as many sub-buffers as the number of
	--! parallel processors;
	--! Every sub-buffer has its own memory bus: address and data;
	--! This control unit must provide the addresses that access every sub-buffer;
	--! The data accessed by the addresses are output to the frame buffer data
	--! mux; 
	--! The frame buffer data mux has as many mux as the number of parallel
	--! autocorrelation processors; each mux drives the input of an
	--! autocorrealation arithmetic unit;
	--! Every mux is driven by all the sub-buffers of the framebuffer;
	--! This control unit must also provide the selector of every mux in order
	--! to select which sub-buffer will feed the input of the autocorrelation arithmetic
	--! path (in this case, the multiplier and accumulator unit) corresponding
	--! to the respective mux .
	--------------------------------------------------------------------------
	
	setAcFrameBufferSignalInterface:
	for pp in 0 to PARALLELISM_DEPTH_OVER_i-1 generate

		--Frame buffer has two memory interfaces A and B
		--The data addressed at the interfaces will drive the operans of the
		--autocorrelation unit: A (data[i]) and B (data[i+j])
		--Therefore, iLocal addresses interface A and iLocal+jLocal addresses
		--interface B
		acFrameBufferReadAddressB(pp)((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)-1 downto 0) <= i_plus_j_local((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)-1 downto 0);
		acFrameBufferReadAddressA(pp)((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)-1 downto 0) <= iLocal(0)((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)-1 downto 0);
		parallelismGreaterThan1: if (PARALLELISM_DEPTH_OVER_i /= 0) generate
			acFrameBufferReadAddressA(pp)((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)) <= (others => '0');
			acFrameBufferReadAddressB(pp)((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH_OVER_i)) <= (others => '0');

			selAcFrameBufferDataMuxPartialSum(pp)(N_BITS_PARALLELISM_DEPTH_OVER_i downto 0) <= (j_divided_by_i_stride + 1) when (unsigned(i_plus_j_divided_by_i_stride) > unsigned(j_divided_by_i_stride)) else
																								 j_divided_by_i_stride;
		end generate parallelismGreaterThan1;

		selAcFrameBufferDataMuxPartialSum(pp)(ConstMaxNbitsParallelismDepth downto N_BITS_PARALLELISM_DEPTH_OVER_i+1) <= (others => '0');

		setSelAcFrameBufferDataMux: process(rst_n, clk) is
		begin
			if (rst_n = '0') then
				selAcFrameBufferDataMux(pp) <= std_logic_vector(to_unsigned(pp, ConstMaxNbitsParallelismDepth));
			elsif (clk'event and clk = '1') then
				-----------------------------------------------------------------------------
				-- P = PARALLELISM_DEPTH_OVER_i
				-- iStride = W/P = size of the sub-buffer 
				-- selAcFrameBufferDataMux(sub-bufer pp) = 	pp + 	{ j/iStride + 1			if [ (i+j)/iStride > j/iStride ]
				-- 													{ j/iStride 			if [ (i+j)/iStride = j/iStride ]
				--
				-- 
				-- The sub-buffer that must drive the operand B of the
				-- autocorrelation unit pp is the one that holds the data
				-- addressed by i+j
				-- As (W/P) is the size of a sub-buffer, that sub-buffer is
				-- located (i+j)/(W/P) sub-buffers after the one indexed by pp:
				-- pp + (i+j)/(W/P)
				-- Should the value (i+j)/(W/P) goes beyond the number of
				-- sub-buffers, there is no data to be fed to the operand B of
				-- autocorrelation unit pp;
				-- the selected sub-buffer of mux pp
				-- is therefore given by PARALLELISM_DEPTH_OVER_i, which means
				-- data provision to the autocorrelation unit pp is pp, thereby
				-- disabling that unit
				selAcFrameBufferDataMuxStage1(pp) <= selAcFrameBufferDataMuxPartialSum(pp) + pp;
				if (to_integer(unsigned(selAcFrameBufferDataMuxStage1(pp))) >= PARALLELISM_DEPTH_OVER_i) then
					selAcFrameBufferDataMux(pp) <= std_logic_vector(to_unsigned(PARALLELISM_DEPTH_OVER_i, ConstMaxNbitsParallelismDepth));
				else
					selAcFrameBufferDataMux(pp) <= selAcFrameBufferDataMuxStage1(pp)(ConstMaxNbitsParallelismDepth-1 downto 0);
				end if;
			end if;
		end process setSelAcFrameBufferDataMux;

		enableMac(pp) <= '1';
		
	end generate setAcFrameBufferSignalInterface;
	


	

	-- It raises a signal to start calculating the temporal mean of pixels at the
	-- state: StateCalculateTemporalMeanOfPixels
	startCalculatingTemporalMeanOfPixels <= '1' when (state = StateCalculateTemporalMeanOfPixels) else '0';

	-- It raises a pulse to end calculating the temporal mean of pixels at the
	-- state: StateLoopOverTheFrame -> StateCalculateTemporalMeanOfPixels, so that
	-- state StateEndCalculatingTemporalMeanOfPixels waits for the calculation to complete
	endCalculatingTemporalMeanOfPixels <= '1' when (state = StateEndCalculatingTemporalMeanOfPixels) else '0';


	
	-----------------------------------------------------------------------
	--! \brief purpose: Combinational process to set outputs according to states of processes
	----------------------------------------------------------------------
	procSetOutputs: process (stateProcLoopOverThePast, iLatency, end_of_iLatency_loop, load_cjLocal, jLatency) is
	begin  -- process procSetOutputs
		-- For every concurrent autocorrelation unit on j ...
		for jj in 0 to temporalParallelismDepth_j-1 loop

			-- When the pipeline is fed with the operations of ( p(i) - mean(p) )( p(i+j) - mean(p)
			-- ), and for every loop of the iterator i, the accumulator of the autocorrelation must be set to the first
			-- partial sum ( p(0) - mean(p) )( p(j) - mean(p) ) of the loop
			if (stateProcLoopOverThePast(jj) = StateFeedAcPipeline) then
				setAccumulator(jj) <= '1';
			elsif (stateProcLoopOverThePast(jj) = StateLoopOverThePast and iLatency(jj) = end_of_iLatency_loop(jj)) then
				setAccumulator(jj) <= '1';
			elsif (stateProcLoopOverThePast(jj) = StateWaitForPipeline and iLatency(jj) = end_of_iLatency_loop(jj)) then
				setAccumulator(jj) <= '1';
			else 
				setAccumulator(jj) <= '0';
			end if;
			
			-- For every loop of the iterator i over the past, the final result of
			-- the accumulation must be stored in register c_j, and the register that holds the multiplication <p>^2*(W-j)
			-- must be decremented by <p>^2, so that the operands of the division
			-- c(j)/(mean(p)^2 * (W-j)) are ready for the division to the
			-- place in the next i loop.
			-- The final result of the autocorrelation's accumulator is loaded to cj latency cycles after i finished the
			-- loop, which is when iLatency finishes its loop, which happens during
			-- states StateLoopOverThePast and StateWaitForPipeline
			if (stateProcLoopOverThePast(jj) = StateLoopOverThePast and unsigned(iLatency(jj)) = unsigned(end_of_iLatency_loop(jj))) then
				load_cjLocal(jj) <= '1';
			elsif (stateProcLoopOverThePast(jj) = StateWaitForPipeline and unsigned(iLatency(jj)) = unsigned(end_of_iLatency_loop(jj))) then
				load_cjLocal(jj) <= '1';
			else 
				load_cjLocal(jj) <= '0';
			end if;

			load_cj(jj) <= load_cjLocal(jj);
			
			-- The value of <p>^2*(W-j) must only be decremented by <p>^2 when
			-- jLatency > 0, because, for the jLatency=0, its value must hold <p>^2*W
			-- This value is decreased by <p>^2 at every subsequent increment
			-- of jLatency, so that <p>^2*(W-j) holds true
			if (jLatency(jj) > 0) then
				decrementSquareOfTemporalMeanTimesWminus_j(jj) <= load_cjLocal(jj);
			else
				decrementSquareOfTemporalMeanTimesWminus_j(jj) <= '0';
			end if;
		end loop;
		
	end process procSetOutputs;
	


	-----------------------------------------------------------------------
	--! \brief purpose: Sequential process to set outputs set/accumulateCj
	--! according to states of processes
	----------------------------------------------------------------------
	procSetCjControl: process (clk, rst_n, nLocal, load_cjLocal) is
	begin  -- process procSetCjControl
		-- For every concurrent autocorrelation unit on j ...
		for jj in 0 to temporalParallelismDepth_j-1 loop

			if (rst_n = '0') then
				setCj(jj) <= '0';
				accumulateCj(jj) <= '0';
			elsif (clk'event and clk = '1') then
				-- For every loop of the iterator i over the past, the final result of
				-- the accumulation is stored in register c_j
				-- While the present autocorrelation c_j(t) is being calculated during the current loop,
				-- the c_j(t+1) obtained in the past loop is divided by 
				-- (mean(p)^2 * (W-j)) and accumulated in register C[j] by
				-- accumulateCj (If this is the first i and j itertation over the
				-- frame - n = 0, it raises setCj instead of accumulateCj).
				-- The division is obtained Ld cycles after accumulation is stored
				-- in c_j, where Ld is the divider latency.
				-- This division takes places in the states StateLoopOverThePast,
				-- StateWaitForPipeline
				if (nLocal(0) = 0) then
					setCj(jj) <= load_cjLocal(jj);
					accumulateCj(jj) <= '0';
				else
					setCj(jj) <= '0';
					accumulateCj(jj) <= load_cjLocal(jj);
				end if;
			end if;
		end loop;
		
	end process procSetCjControl;		

	--!@brief It tells the FrameBuffer to update its content with the next set of
	--! frames to calculate the autocorrelation on when it finishes to loop over
	--! the frame's indexes
	generateGetNextSetOfFramesInStreamingMode:
	if (mode = 0) generate
		getNextSetOfFrames <= '1' when (state = StateLoopOverTheFrame and nLocal(0) = nStride) else '0';
	end generate generateGetNextSetOfFramesInStreamingMode;	

	generateGetNextSetOfFramesInTriggerMode:
	if (mode /= 0) generate
		getNextSetOfFrames <= '1' when (vaiAutocorrelationStage2 = '1' and state = StateInit) else '0';
	end generate generateGetNextSetOfFramesInTriggerMode;	


	--It outputs indexes
	n <= nLocal;
	i <= iLocal;
	j <= jLocal;
	jCjBuffer <= jDividerLatency;


end architecture acControlUnit1;
