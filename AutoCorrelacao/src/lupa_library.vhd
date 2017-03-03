-----------------------------------------
--! @file
--! @brief 2:1 It implements constants, types and tools used by the modules in
--!				the Lupa project
--------------------------------------------------------------------------------------------
--------------------               wandson@ivision.ind.br   ---------------------------------
--------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.math_real.all;

package lupa_library is
	-- Contants
	constant ConstFrameSize 	: natural := 128; 
	constant FPGA_LINES_TO_ACCEPT : natural := 2;
	constant W 	: natural := 4096; 
	constant N_BITS_FRAME_SIZE: natural := integer(ceil(log2(real(ConstFrameSize)))); 	--! Number of bits to represent the number of pixels of image frame
	constant N_BITS_TIME_WINDOW : natural := integer(ceil(log2(real(W))));
	
	constant PXLS_TO_SAVE : natural := (ConstFrameSize+2)*(W);
	
	constant N_BITS_TIME_WINDOW_TO_MEMORY : natural := 10;--10;
	
	constant N_BITS_MAX_TIME_WINDOW : natural := 13;
	


	constant N_BITS_RATIONAL_DEFAULT: natural := 64;																									--! Default number of bits of both integer and rational halves of rational signals

	
	constant N_BITS_FRAC_DEFAULT : natural := 32;
	constant N_BITS_INT_DEFAULT : natural := N_BITS_RATIONAL_DEFAULT - N_BITS_FRAC_DEFAULT;

	constant N_BITS_DIVIDER_NUM : natural := 64;
	constant N_BITS_DIVIDER_DEN : natural := 64;
	
	constant N_BITS_DATA : natural := 8;
	constant N_BITS_SIGN : natural := 1;        
	constant N_BITS_FRAC : natural := 5;

	
	constant N_BITS_MULTIPLIER : natural := N_BITS_DATA + N_BITS_SIGN + N_BITS_FRAC;


	
	constant N_BITS_MAX_DATA 		: natural := N_BITS_DATA;
	
	constant N_BITS_ADDRESS_OF_V200_MEMORY_CONTROLLER_FIFO 	: natural := 10;
	
	constant N_BITS_MEAN_INT : natural := 8;
	constant N_BITS_MEAN_FRAC : natural := 10;
	constant N_BITS_MEAN_TOTAL : natural := N_BITS_MEAN_INT+N_BITS_MEAN_FRAC;
	
	constant N_BITS_MEAN_SQR_INT : natural := 2*N_BITS_MEAN_INT;
	constant N_BITS_MEAN_SQR_FRAC : natural := N_BITS_MEAN_FRAC;
	constant N_BITS_MEAN_SQR_TOTAL : natural := N_BITS_MEAN_SQR_FRAC + N_BITS_MEAN_SQR_INT;
	

	constant N_BITS_ACC_OUTPUT_INT : natural := N_BITS_MEAN_SQR_INT+
												2*N_BITS_MAX_TIME_WINDOW;
	
	constant N_BITS_ACC_OUTPUT_FRAC : natural := N_BITS_MEAN_SQR_FRAC;
	constant N_BITS_ACC_TOTAL : natural := 2*N_BITS_MULTIPLIER + N_BITS_TIME_WINDOW + N_BITS_FRAME_SIZE; 
	constant N_BITS_ACC_OUTPUT_TOTAL : natural := 32; --N_BITS_ACC_OUTPUT_FRAC + N_BITS_ACC_OUTPUT_INT;

	constant N_BITS_MEAN_SQR_TIMES_W_INT : natural := N_BITS_ACC_OUTPUT_INT;
	constant N_BITS_MEAN_SQR_TIMES_W_FRAC : natural := N_BITS_ACC_OUTPUT_FRAC;
	constant N_BITS_MEAN_SQR_TIMES_W_TOTAL : natural := N_BITS_MEAN_SQR_TIMES_W_FRAC + N_BITS_MEAN_SQR_TIMES_W_INT;


	
	constant N_BITS_PXL_AC_RESULT_FRAC  : natural := N_BITS_DIVIDER_NUM - N_BITS_ACC_OUTPUT_TOTAL +
													 2*N_BITS_MEAN_FRAC - N_BITS_ACC_OUTPUT_FRAC;
	constant N_BITS_PXL_AC_RESULT_INT   : natural := 6;
	constant N_BITS_PXL_AC_RESULT_TOTAL : natural := N_BITS_ACC_OUTPUT_TOTAL;
	constant N_BYTES_PXL_AC_RESULT_TOTAL : natural := N_BITS_PXL_AC_RESULT_TOTAL / 8;
	constant N_BYTES_MINUS_1_PXL_AC_RESULT_TOTAL : natural := N_BYTES_PXL_AC_RESULT_TOTAL - 1;
	
	
	constant N_BITS_RATIONAL : natural := N_BITS_RATIONAL_DEFAULT;	--! Number of bits of the rational representation

	constant NbitsOfV200MemoryControllerImageSize 	: natural := 20; 	--! Number of bits of image size of V200 memory controller
	constant NbitsOfBurstOfV200MemoryController 	: natural := 4; 	--! Number of bits of burst of V200 memory controller (burst size = 512)
	constant NbitsOfExternalMemoryAddress 			: natural := 32; 	--! Number of bits of address of the V200 external memory controller

	constant N_BITS_MULTIPLE_ADDER_OPERAND 			: natural := N_BITS_ACC_TOTAL;


	--!Pipelines
	
	constant DIVIDER_PIPELINE_CYCLES : natural := 64;
	constant MultiplierPipelineCycles 				: natural := 8;
	constant CoreUnitExtraCycles 					: natural := 3; 
	constant FrameBufferLatency 					: natural := 2; 
	constant ConstPipelineDepth 					: natural := MultiplierPipelineCycles+CoreUnitExtraCycles
																 + FrameBufferLatency; 										--! Number of cycles of the autocorrelation unit's pipeline +1 (which is the time the frame buffer takes to output the pixels addressed by i and i+j)
	constant DividerPipelineCycles 					: natural := DIVIDER_PIPELINE_CYCLES;
	constant DivisionUnitExtraCycles 				: natural := 1;
	constant ConstDividerPipelineDepth 				: natural := DividerPipelineCycles + DivisionUnitExtraCycles; 			--! Number of cycles of the divider's pipeline-1
	constant ConstFrameBufferReadLatency 			: natural := 3; 														--! FrameBuffer and Cj buffer latencies

	--! Values of selection of the operands of the AC's multiplier
	
	--! It selects the partial sum of the autocorrelation: ( p(i) - mean(p) )( p(i+j) - mean(p) )
	constant ConstSelectSquareOfMeanOfPixel: std_logic_vector(1 downto 0) := "10";
	--! It selects the temporal mean of the pixels as both operands
	constant ConstSelectAcPartialSum: std_logic_vector(1 downto 0) := "01";
	--! It selects the square of the temporal mean and W-j
	constant ConstSelectSquareOfMeanTimesWinusJ: std_logic_vector(1 downto 0) := "00";

	--! Values of selection of the operands of the AC's divider
	--! It selects the sum of pixels and the time window as the operands
	constant ConstMeanPixels: std_logic := '1';
	--! It selects the result of the AC's accumulator (c_j) and, according to
	--! the equation mean(p)^2 * (W-j)
	constant ConstAccumulatorDividedBySquareOfMeanPixelsTimesW: std_logic := '0';

	--! Default values for time window and frame size
	constant ConstDefaultTimeWindow 		: positive := 1024; 
	constant ConstDefaultFrameSize 			: positive := 16; 
	constant ConstDefaultNbitsTimeWindow 	: positive := 10; 
	constant ConstDefaultNbitsFrameSize		: positive := 4; 
	--! Maximum values fo time window and frame size
	constant ConstMaxTimeWindow 		: positive := 1024;
	constant ConstMaxFrameSize 			: positive := 512;


	constant temporalParallelismDepth : natural := 1;

	constant ConstDefaultParallelismDepth 	: natural := 1;
	constant ConstDefaultNbitsParallelismtDepth 	: natural := 0;
	constant ConstMaxParallelismDepth 	: natural := 256;
	constant ConstMaxNbitsParallelismDepth 	: natural := 8;


	-- Custom types
	--type rational_mean is (std_logic_vector((N_BITS_INTEGER_MEAN-1) downto 0), std_logic_vector((N_BITS_RATIONAL_MEAN-1) downto 0)); 					--! Type to represent the temporal mean of pixels	
	--type rational_mean_square is (std_logic_vector((N_BITS_INTEGER_MEAN_SQUARE-1) downto 0), std_logic_vector((N_BITS_RATIONAL_MEAN_SQUARE-1) downto 0)); --! Type to represent the square temporal mean of pixels
	--type rational_mean_square_times_n is (std_logic_vector((N_BITS_INTEGER_MEAN_SQUARE_N-1) downto 0), std_logic_vector((N_BITS_RATIONAL_MEAN_SQUARE_N-1) downto 0)); --! Type to represent the square temporal mean of pixels times frame size
	--type rational_c_j is (std_logic_vector((N_BITS_INTERMEDIATE_AC_INTEGER-1) downto 0), std_logic_vector((N_BITS_INTERMEDIATE_AC_RATIONAL-1) downto 0)); --! Type to represent the Intermadiate result of autocorrelation for a given iterator j

	--! It represents a rational type
	type rational is record
		content: std_logic_vector(N_BITS_RATIONAL-1 downto 0);	--! Bit vector
		pointPosition: natural;
--! From the MSB bit, position where point is, so that the bit sizes are:
--ingeter part: pointPosition, rational part: N_BITS_RATIONAL - pointPosition
	end record rational;											 

	type TypeArrayOfSpacialIndexes is array(0 to ConstMaxFrameSize-1) of std_logic_vector(N_BITS_FRAME_SIZE downto 0);		--! array of spacial indexes; there are as many indexes as there are autocorrelation units that processes concurrently for different indexes in image frame
	type TypeArrayOfTemporalIndexes is array(0 to ConstMaxTimeWindow-1) of std_logic_vector(N_BITS_TIME_WINDOW downto 0);	--! array of temporal indexes; there are as many indexes as there are autocorrelation units that processes concurrently for different values of j	

	type TypeArrayOfReadAdressesOfFrameBuffer is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(N_BITS_MAX_TIME_WINDOW-1 downto 0);	
	type TypeArrayOfOutputDataOfFrameBuffer is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(N_BITS_MAX_DATA-1 downto 0);
	type TypeArrayOfOutputDataOfFrameBufferFrac is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(N_BITS_DATA+N_BITS_FRAC-1 downto 0);
	type TypeArrayOfFrameBufferMuxSelect is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(ConstMaxNbitsParallelismDepth-1 downto 0);
	type TypeArrayOfNbitsParallelismDepthPlus1 is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(ConstMaxNbitsParallelismDepth downto 0);
	type TypeArrayOfMultipleAdderOperands is array(0 to ConstMaxParallelismDepth-1) of std_logic_vector(N_BITS_MULTIPLE_ADDER_OPERAND-1 downto 0);

	-- Functions
	function compat_fixed_point ( sig_to_compat_int : std_logic_vector;
								  sig_to_compat_frac : std_logic_vector;
								  n_bits_final_frac : integer;
								  n_bits_final_total : integer) return std_logic_vector; 																	--! Funcao para compatibilizar operacoes com diferentes tamanos de ponto fixo N.M

end lupa_library;


package body lupa_library is
	function compat_fixed_point ( sig_to_compat_int : std_logic_vector;
								  sig_to_compat_frac : std_logic_vector;
								  n_bits_final_frac : integer;
								  n_bits_final_total : integer)
		return std_logic_vector is
		variable n_bits_final_int : integer := n_bits_final_total - n_bits_final_frac;
		variable result_int : std_logic_vector(n_bits_final_int-1 downto 0) := (others => '0');
		variable result_frac : std_logic_vector(n_bits_final_frac-1 downto 0) := (others => '0');
		variable n_bits_sig_int : integer := sig_to_compat_int'length;
		variable n_bits_sig_frac : integer := sig_to_compat_frac'length;
		
	begin
		if n_bits_sig_int > n_bits_final_int then
			result_int :=  sig_to_compat_int(result_int'length-1 + sig_to_compat_int'right downto sig_to_compat_int'right);
		else
			result_int(n_bits_sig_int-1 downto 0) :=  sig_to_compat_int;
		end if;

		if n_bits_sig_frac > n_bits_final_frac then
			result_frac :=  sig_to_compat_frac(n_bits_sig_frac-1 downto n_bits_sig_frac - n_bits_final_frac);
		else
			result_frac(n_bits_final_frac-1 downto n_bits_final_frac - n_bits_sig_frac) :=  sig_to_compat_frac;
		end if;
		return result_int & result_frac;
	end compat_fixed_point;
	
end lupa_library;



