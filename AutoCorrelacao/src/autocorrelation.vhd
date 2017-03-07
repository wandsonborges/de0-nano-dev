-------------------------------------------------------------------------------
--! @file autocorrelation.vhd
--! @author wandson@ivision.ind.br
--! @brief Autocorrelation unit
-------------------------------------------------------------------------------
-- File       : autocorrelation.vhd
-- Author     : Wandson Borges  <wandson@ivision.ind.br>
-- Company    : 
-- Created    : 2016-02-12
-- Last update: 2017-03-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2016-02-12  1.0      wandson	Created
-------------------------------------------------------------------------------

library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
use IEEE.math_real.all;



-------------------------------------------------------------------------------
--! @brief Design unit that performs temporal autocorrelation of frames over a time
--! window
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
--! c(j) = [ Sum{from i=0 to i=W-j}( p(i) - mean(p) )( p(i+j) - mean(p) ) ]
--!
--! It implements the Control Unit (UC) of the autocorrelation's architecture:
--!
--! \image html doc/auto-correlation-unit.png
--!
--!
--! A detailed data path depiction of the arithmetic unit:
--!
--! @image html doc/ac-data-path.png
-------------------------------------------------------------------

entity autocorrelation is
	
	generic (
		mode 					 	: natural 	:= 1;  						--! Behaviour of this module: 0 - mode streaming - it continuouslly outputs autocorrelation; 1 - mode trigger - it triggers calculation of autocorrelation upon rise of signal vaiAutocorrelation
		PARALLELISM_DEPTH 			: natural := 1
		);

	port (
		--Intpus
		
		clk							  : in	std_logic;
		nrst						  : in	std_logic;

		-- Avalon slave input: control
		acSlaveRead 						: in std_logic;
		acSlaveWrite 						: in std_logic;
		acSlaveAddress						: in std_logic_vector(12 downto 0); --(N_BITS_TIME_WINDOW-1 downto 0);
		acSlaveByteEnable					: in std_logic_vector(3 downto 0);
		acSlaveWriteData					: in std_logic_vector(31 downto 0); --(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0);

                chipselect                                              : in std_logic;

		memoryControllerBusy					: in std_logic; 						--! it flags '1' when v200's memory controller is busy

		-- Avalon master input
		acMasterWaitRequest 				: in std_logic;
		acMasterReadDataValid 				: in std_logic;
		acMasterReadData					: in std_logic_vector(7 downto 0); 	--! Data read from external memory

		dataBeingWrittenToExternalMemory 	: in std_logic; 		--! it flags '1' when there is data being written to external memory		


		--Outputs

		--Avalon slave output: control
		acSlaveWaitRequest 					: out std_logic;
		acSlaveReadDataValid 				: out std_logic;
		acSlaveReadData						: out std_logic_vector(31 downto 0); --(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0); 	--! Data read from external memory

		-- Avalon master output
		acMasterRead 						: out std_logic;
		acMasterAddress						: out std_logic_vector(31 downto 0); --(NbitsOfExternalMemoryAddress-1 downto 0);
		acMasterBurstCount					: out std_logic_vector(3 downto 0);
		acMasterByteEnable					: out std_logic;

		enableSensorDataToExternalMemory 	: out std_logic 	--! when '1', it enables the module that writes data to the external memory to write the data that will be the input of the autocorrelation process

		);

end entity autocorrelation;





architecture autocorrelation1 of autocorrelation is


	constant N_BITS_PARALLELISM_DEPTH 		: integer := integer(ceil(log2(real(PARALLELISM_DEPTH))));
	
	constant window_of_frames : std_logic_vector(N_BITS_TIME_WINDOW downto 0)
		:= std_logic_vector(to_unsigned(W, N_BITS_TIME_WINDOW+1));

signal vaiAutocorrelation 			  : 	std_logic; 									--! it fires autocorrelation		


signal rst_n : std_logic;
signal write_pxl : std_logic;
signal frameBufferReady								 	: std_logic; 
signal acSpacialMeanCalculationDone					 	: std_logic; 
signal selMultiplierOperands							: std_logic_vector(1 downto 0); 
signal selDividerOperands								: std_logic; 
signal startCalculatingTemporalMeanOfPixels			 	: std_logic; 
signal endCalculatingTemporalMeanOfPixels		 		: std_logic;
signal startCalculatingSquareOfTemporalMeanOfPixels	 	: std_logic; 
signal startCalculatingSquareOfTemporalMeanTimesW 		: std_logic; 
signal startCalculatingSpacialMeanOfAc					: std_logic; 
signal setAccumulator									: std_logic_vector(temporalParallelismDepth-1 downto 0);
signal load_cj											: std_logic_vector(temporalParallelismDepth-1 downto 0);
signal decrementSquareOfTemporalMeanTimesWminus_j		: std_logic_vector(temporalParallelismDepth-1 downto 0);
signal accumulateCj									 	: std_logic_vector(temporalParallelismDepth-1 downto 0);
signal setCj											: std_logic_vector(temporalParallelismDepth-1 downto 0);
signal getNextSetOfFrames								: std_logic; 
signal bufferNextTimeWindow								: std_logic;
signal timeWindowReady 									: std_logic;
signal CjByteSelector									: natural;
signal n												: TypeArrayOfSpacialIndexes; 
signal j												: TypeArrayOfTemporalIndexes;
signal i												: TypeArrayOfTemporalIndexes;
signal jCjBuffer										: TypeArrayOfTemporalIndexes;

signal pxl_correlation_result      : std_logic_vector(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0);
signal pxl_mean_square             : std_logic_vector(N_BITS_MEAN_SQR_TOTAL -1 downto 0);
signal pxl_data                    : std_logic_vector(N_BITS_DATA-1 downto 0);
signal pxl_valid_in                : std_logic;
signal start_frame_correation_calc : std_logic;
signal divider_output              : std_logic_vector(N_BITS_DIVIDER_NUM -1 downto 0);
signal req_pxl_to_sum              : std_logic;
signal divider_done                : std_logic;

signal pxl_mean                     : std_logic_vector(N_BITS_MEAN_TOTAL -1 downto 0);
signal pxl_data_i                   : std_logic_vector(N_BITS_DATA-1 downto 0);
signal pxl_data_j                   : std_logic_vector(N_BITS_DATA-1 downto 0);
signal pxls_valid_in                : std_logic;
signal clear_acc                    : std_logic;
signal mean_sqr_output              : std_logic_vector(N_BITS_MEAN_SQR_TOTAL -1 downto 0);
signal mean_sqr_times_wj_output     : std_logic_vector(N_BITS_MEAN_SQR_TIMES_W_TOTAL-1 downto 0);
signal accumulator_output           : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
signal sumOfMultipliersResult           : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
signal multiplier_done              : std_logic;





  signal pxl_temp_mean_output        : std_logic_vector(N_BITS_MEAN_TOTAL -1 downto 0);
  signal pxl_correlation_output      : std_logic_vector(N_BITS_PXL_AC_RESULT_TOTAL -1 downto 0);
  signal pxl_correlation_acc_output  : std_logic_vector(N_BITS_PXL_AC_RESULT_TOTAL -1 downto 0);


signal pxl_to_write       : std_logic_vector(N_BITS_DATA-1 downto 0);
signal n1_in              : std_logic_vector(N_BITS_FRAME_SIZE downto 0);
signal w1_in              : std_logic_vector(N_BITS_TIME_WINDOW downto 0);
signal data1_out          : std_logic_vector(N_BITS_DATA-1 downto 0);
signal n2_in              : std_logic_vector(N_BITS_FRAME_SIZE downto 0);
signal w2_in              : std_logic_vector(N_BITS_TIME_WINDOW downto 0);
signal i_plus_j           : std_logic_vector(N_BITS_TIME_WINDOW downto 0);
signal data2_out          : std_logic_vector(N_BITS_DATA-1 downto 0);

signal frameBufferReadAddress1           : std_logic_vector(N_BITS_TIME_WINDOW-1 downto 0);
signal frameBufferReadAddress2           : std_logic_vector(N_BITS_TIME_WINDOW-1 downto 0);
signal pixelIndex 						: std_logic_vector(N_BITS_FRAME_SIZE-1 downto 0);

signal vsync_flop1, vsync_flop2, vsync_rise_edge : std_logic := '0';
signal busy_flop1, busy_flop2, busy_fall_edge : std_logic := '0';

signal frame_buffer_en : std_logic := '0';
signal busyLocal 				: std_logic;

signal clear_jIndex 		: std_logic;
signal load_jIndex 			: std_logic;
signal dec_jIndex 			: std_logic;
signal feedAcOut 			: std_logic;
signal dataInterfaceBusy 	: std_logic;

signal acFrameBufferReadAddressA 	: TypeArrayOfReadAdressesOfFrameBuffer;
signal acFrameBufferReadAddressB 	: TypeArrayOfReadAdressesOfFrameBuffer;
signal acFrameBufferDataA 			: TypeArrayOfOutputDataOfFrameBuffer;
signal acFrameBufferDataB 			: TypeArrayOfOutputDataOfFrameBuffer;
signal acMultiplexedDataA 			: TypeArrayOfOutputDataOfFrameBufferFrac;
signal acMultiplexedDataB 			: TypeArrayOfOutputDataOfFrameBufferFrac;
signal selAcFrameBufferData 		: TypeArrayOfFrameBufferMuxSelect;
signal accumulator_output_array 	: TypeArrayOfMultipleAdderOperands;
signal enableMac 					: std_logic_vector(PARALLELISM_DEPTH-1 downto 0);

signal autocorrelationResultData : std_logic_vector(15 downto 0) := (others => '0');
signal probelocal : std_logic_vector(15 downto 0) := (others => '0');

signal fake_pixel : std_logic_vector(7 downto 0) := (others => '0');

signal pxl_mean_j : std_logic_vector(N_BITS_DATA + N_BITS_FRAC -1 downto 0);

signal disable_multiplier : std_logic := '0';

signal acCorrelationBufferAddr, acCorrelationBufferSlaveAddr           : std_logic_vector(N_BITS_TIME_WINDOW-1 downto 0);



type state_type is (st_wait_for_vai, st_feed_frame_buffer, st_wait_finish_ac, st_wait_vsync_down);
signal state : state_type := st_wait_for_vai;

begin  -- architecture autocorrelation1

  rst_n <= nrst;

  i_plus_j <= std_logic_vector(unsigned(i(0)) + unsigned(j(0)));


  
	acControlUnit_1: entity work.acControlUnit
		generic map (
			mode 					   => mode,
			spacialParallelismDepth	   => 1,
			temporalParallelismDepth_j => 1,
			PARALLELISM_DEPTH_OVER_i => PARALLELISM_DEPTH,
			nStride					   => ConstFrameSize,
			jStride					   => W
			)
		port map (
			clk												 => clk,
			rst_n											 => nrst,
			vaiAutocorrelation 								 => vaiAutocorrelation,
			frameBufferReady								 => frameBufferReady,
			temporalMeanCalculationDone						 => divider_done,
			squareOfTemporalMeanCalculationDone				 => multiplier_done,
			squareOfTemporalMeanTimesWDone					 => multiplier_done,
			acSpacialMeanCalculationDone					 => divider_done,
			memoryControllerBusy 							 => memoryControllerBusy,
			clear_jDividerLatencyFromDataInterface 			 => clear_jIndex,
			load_jDividerLatencyFromDataInterface			 => load_jIndex,
			decrement_jDividerLatencyFromDataInterface 		 => dec_jIndex,
			dataInterfaceBusy 								 => dataInterfaceBusy,
			startCalculatingTemporalMeanOfPixels			 => startCalculatingTemporalMeanOfPixels,
			endCalculatingTemporalMeanOfPixels				 => endCalculatingTemporalMeanOfPixels,
			setAccumulator									 => setAccumulator,
			load_cj											 => load_cj,
			decrementSquareOfTemporalMeanTimesWminus_j 		 => decrementSquareOfTemporalMeanTimesWminus_j,
			accumulateCj									 => accumulateCj,
			setCj 	 										 => setCj,
			getNextSetOfFrames								 => getNextSetOfFrames,
			getNextTimeWindow 								=> bufferNextTimeWindow,
			dataBeingWrittenToExternalMemory 				=> dataBeingWrittenToExternalMemory,
			timeWindowReady 								=> timeWindowReady,
			enableSensorDataToExternalMemory				=> enableSensorDataToExternalMemory,
			busy 											 => busyLocal,
			n 												 => n,
			j												 => j,
			i												 => i, 
			jCjBuffer 										 => jCjBuffer,
			acFrameBufferReadAddressA 						=> acFrameBufferReadAddressA,
			acFrameBufferReadAddressB 						=> acFrameBufferReadAddressB,
			selAcFrameBufferDataMux 						=> selAcFrameBufferData,
			enableMac 										=> enableMac
			);

	  
  ac_frame_buffer_2: entity work.ac_frame_buffer
	  generic map (
		  FRAME_SIZE  => ConstFrameSize,
		  N_BITS_FRAME_SIZE => N_BITS_FRAME_SIZE,
		  W			  => W,
		  N_BITS_DATA => N_BITS_DATA,
		  PARALLELISM_DEPTH => PARALLELISM_DEPTH
		  )
	  port map (
		  clk									=> clk,
		  rst_n									=> nrst,
		  getNextTimeWindow						=> bufferNextTimeWindow,
		  pixelIndex							=> n(0)(N_BITS_FRAME_SIZE-1 downto 0),
		  readAddressA							=> acFrameBufferReadAddressA,
		  readAddressB							=> acFrameBufferReadAddressB,
		  dataOutA								=> acFrameBufferDataA,
		  dataOutB								=> acFrameBufferDataB,
		  memoryDataReady 						=> memoryControllerBusy,
		  acMasterWaitRequest 				 	=> acMasterWaitRequest,
		  acMasterReadDataValid 				=> acMasterReadDataValid,
		  acMasterReadData						=> acMasterReadData,
		  acMasterRead 						 	=> acMasterRead,
		  acMasterAddress						=> acMasterAddress,
		  acMasterBurstCount					=> acMasterBurstCount,
		  frameBufferReady						=> frameBufferReady,
		  timeWindowReady						=> timeWindowReady);
	

  acDataMultiplexer_1: entity work.acDataMultiplexer
	  generic map (
		  PARALLELISM_DEPTH		   => PARALLELISM_DEPTH
		)
	  port map (
		  clk	   => clk,
		  rst_n	   => rst_n,
                  pxl_mean => pxl_mean_j,
		  dataInA  => acFrameBufferDataA,
		  dataInB  => acFrameBufferDataB,
		  dataOutA => acMultiplexedDataA,
		  dataOutB => acMultiplexedDataB,
		  sel	   => selAcFrameBufferData);

  
  ac_media_temporal_calc_1: entity work.ac_media_temporal_calc
    generic map (
      N_BITS_PXL        => N_BITS_DATA,
      PARALLELISM_LEVEL => PARALLELISM_DEPTH,
      N_BITS_TW         => N_BITS_TIME_WINDOW)
    port map (
      clk          => clk,
      rst_n        => rst_n,
      pxls_input   => acFrameBufferDataA,
      start_sum    => startCalculatingTemporalMeanOfPixels,
      load_mean    => endCalculatingTemporalMeanOfPixels,
      pxl_mean_out => pxl_mean_j);
  
generateMacs: for pp in 0 to PARALLELISM_DEPTH-1 generate
  ac_multiplier_acc_unit_pp: entity work.ac_multiplier_acc_unit
    generic map (
      N_BITS_PXL_DATA            => N_BITS_DATA,
      N_BITS_ACC_TOTAL           => N_BITS_ACC_TOTAL,
      MULTIPLIER_PIPELINE_CYCLES => MultiplierPipelineCycles,
      N_BITS_MULTIPLIER          => N_BITS_MULTIPLIER)
    port map (
      clk               => clk,
      rst_n             => rst_n,
      en                => '1',
      cs 		=> enableMac(pp),
      pxl_mean          => pxl_mean_j,
      pxl_data_i        => acMultiplexedDataA(pp),
      pxl_data_i_plus_j => acMultiplexedDataB(pp),
      result        => accumulator_output_array(pp));
end generate generateMacs;  


			  acMultipleAdder_1: entity work.acMultipleAdder
				  generic map (
					  numberOfOperands		=> PARALLELISM_DEPTH,
					  index					=> 0)
				  port map (
					  clk	 => clk,
					  rst_n	 => rst_n,
					  dataIn => accumulator_output_array,
					  result => sumOfMultipliersResult);
			  

			  acAccumulator_1: entity work.acAccumulator
				  generic map (
					  N_BITS_ACC_TOTAL => N_BITS_ACC_TOTAL)
				  port map (
					  clk				=> clk,
					  rst_n				=> rst_n,
					  en				=> '1',
					  multiplier_result => sumOfMultipliersResult,
					  clear_acc			=> setAccumulator(0),
					  load_acc			=> load_cj(0),
					  acc_result		=> accumulator_output);



			  avalonControlSlaveDecoder_1: entity work.avalonControlSlaveDecoder
				  port map (
					  clk					  => clk,
					  nrst					  => nrst,
					  acSlaveRead			  => acSlaveRead,
					  acSlaveWrite			  => acSlaveWrite,
					  acSlaveAddress		  => acSlaveAddress,
					  acSlaveByteEnable		  => acSlaveByteEnable,
					  acSlaveWriteData		  => acSlaveWriteData,
                                          chipselect                      => chipselect,
					  busy					  => busyLocal,
					  acCorrelationBufferData => pxl_correlation_acc_output,
					  acSlaveWaitRequest	  => acSlaveWaitRequest,
					  acSlaveReadDataValid	  => acSlaveReadDataValid,
					  acSlaveReadData		  => acSlaveReadData,
					  vaiAutocorrelation	  => vaiAutocorrelation,
					  acCorrelationBufferAddr => acCorrelationBufferSlaveAddr);

			  acCorrelationBufferAddr <= jCjBuffer(0)(N_BITS_TIME_WINDOW-1 downto 0) when (busyLocal = '1') else
										 acCorrelationBufferSlaveAddr;
			  
	ac_correlation_result_buffer_1: entity work.ac_correlation_result_buffer
		generic map (
                  N_BITS_INDEX				=> N_BITS_TIME_WINDOW,
                      N_BITS_ACC_OUTPUT_TOTAL           => N_BITS_ACC_OUTPUT_TOTAL,
			NUM_OF_FRAMES				=> W,
			NUM_OF_REG_TO_BUF			=> 4,
			N_BITS_DATA					=> N_BITS_DATA,
			N_BITS_ADDR					=> N_BITS_TIME_WINDOW_TO_MEMORY)
		port map (
			clk						   => clk,
			rst_n					   => rst_n,
			index_j					   => acCorrelationBufferAddr, --jCjBuffer(0)(N_BITS_TIME_WINDOW-1 downto 0),
			acc_corr_j				   => accumulateCj(0),
			set_corr_j				   => setCj(0),
			pxl_correlation_in		   => accumulator_output,
			pxl_correlation_acc_output => pxl_correlation_acc_output);


  dataInterface_2: entity work.dataInterface
	  generic map (
		  W => W,
		  N_BITS_TIME_WINDOW => N_BITS_TIME_WINDOW_TO_MEMORY)
	  port map (
		  clk			  	=> clk,
		  nrst			  	=> '0', --rst_n,
		  Cj				=> pxl_correlation_acc_output,
		  jIndex		  	=> jCjBuffer(0)(N_BITS_TIME_WINDOW_TO_MEMORY downto 0),
		  clkRead		  	=> '0', --clkRead,
		  readCjBuffer	  	=> '0', --readAutocorrelationResult,
		  read			  	=> '0', --read,
		  autocorrelationBusy 	=> busyLocal,
		  clear_jIndex	  	=> clear_jIndex,
		  load_jIndex	  	=> load_jIndex,
		  dec_jIndex 		=> dec_jIndex,
		  busy			  	=> dataInterfaceBusy,
		  CjDataAvailable 	=> open, --autocorrelationResultAvailable,
		  dataOut		  	=> open); --autocorrelationResultData);
  

  
end architecture autocorrelation1;
