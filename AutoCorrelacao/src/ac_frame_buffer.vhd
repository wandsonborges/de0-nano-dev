--! @file ac_frame_buffer.vhd
--! @author wandson@ivision.ind.br
--! @brief It reads and buffers time window from external memory 
--! \image html doc/ac_frame_buffer.png


library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
use IEEE.math_real.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;



-------------------------------------------------------------------------------
--! @brief It implements the Frame Buffer block depicted in the image.
--!
--! \image html doc/ac_frame_buffer.png
-------------------------------------------------------------------------------

entity ac_frame_buffer is
  
	generic (
		FRAME_SIZE          		: natural       := ConstDefaultFrameSize; 					--! Number of pixels in frame
		N_BITS_FRAME_SIZE 			: natural 		:= N_BITS_FRAME_SIZE; 	--! Number of bits of FRAME_SIZE
		W 							: natural   	:= ConstDefaultTimeWindow; 					--! Time window
		N_BITS_DATA         		: integer       := 8;										--! Number of bits of data in frame buffer
		PARALLELISM_DEPTH 			: natural 		:= ConstDefaultParallelismDepth 			--! Number of units of autocorrelation processing pixels concurrently for different values of i, where i iterates the pixels temporally		
		);

	port (
		clk, rst_n         		: in  std_logic;

		-- Signals coming from the control unit
		getNextTimeWindow		: in std_logic;											--! A pulse in this port signals the module to retrieve the time window from external memory
		pixelIndex 				: in std_logic_vector(N_BITS_FRAME_SIZE-1 downto 0); 	--! The pixel index in the frame whose time window is to be retrieved 
		readAddressA 			: in TypeArrayOfReadAdressesOfFrameBuffer; 				--! Interface A's address of data to be read from frame buffer
		readAddressB 			: in TypeArrayOfReadAdressesOfFrameBuffer; 				--! Interface B's address of data to be read from frame buffer

		--Data read from the frame buffer output to the autocorrelation's data path
		dataOutA 	  	 	      						: out TypeArrayOfOutputDataOfFrameBuffer; 	--! Data read from interface A of frame buffer		
		dataOutB 	         							: out TypeArrayOfOutputDataOfFrameBuffer;	--! Data read from interface B of frame buffer

		memoryDataReady 					: in std_logic;

		
		-- Avalon master input
		acMasterWaitRequest 				: in std_logic;
		acMasterReadDataValid 				: in std_logic;
		acMasterReadData					: in std_logic_vector(7 downto 0); 	--! Data read from external memory

		-- Avalon master output
		acMasterRead 						: out std_logic;
		acMasterAddress						: out std_logic_vector(31 downto 0); --(NbitsOfExternalMemoryAddress-1  downto 0);
		acMasterBurstCount					: out std_logic_vector(3 downto 0);

		-- Signals output to the controle unit
		frameBufferReady 					: out std_logic;	--! It signals '1' when this module has started operations
		timeWindowReady 					: out std_logic 	--! It signals '1' when frame buffer is loaded with new time window
		);
  

end entity ac_frame_buffer;

architecture bhv of ac_frame_buffer is

	constant N_BITS_TIME_WINDOW 			: natural := integer(ceil(log2(real(W)))); --! Number of bits of time window
	constant N_BITS_PARALLELISM_DEPTH 		: integer := integer(ceil(log2(real(PARALLELISM_DEPTH))));
	constant ConstReadTimeWindowPulseDepth 	: natural := 4;


	--ProcessTimeWindowBuffer states
	type TypeStateTimeWindowBuffer is (StateInit,

									   StateWriteSensorFramesToExternalMemory,		--It waits for external process that write
																					--data to the external memory to go idle

									   StateEnableGenerateNextAddressProcess,		--It enables process that issues the addresses
																					--that will be prefetched by the external memory controller
									   
									   StateWaitForTimeWindowRequest,				--It waits for the request to the retrieve
																					--next time window from external memory

									   StateStartGetTimeWindowProcess,				--It starts process that retrieve time window
																					--from external memory

									   StateGettingTimeWindow 						--It waits for time window to be retrieved
									   );
	
	type TypeStateGenerateNextAddress is (StateInit,

										  StateIssueFirstAddress,					-- It issues first prefetch address to the
																					--external memory controller

										  StateWaitForFirstAddressToBeGrasped, 		-- It waits for the first prefetch address to be
																					-- grasped by the external memory controller

										  StateIssueSecondAddress, 					-- It issues second prefetch address to the
																					--external memory controller
																					
										  StateWaitForSecondAddressToBeGrasped, 	-- It waits for the second prefetch address to be
																					-- grasped by the external memory controller

										  StateIssueNextAddress,					-- It issues next prefetch address to the
																					-- external memory controller

										  StateWaitForNextAddressToBeGrasped,		-- It waits for the next prefetch address to be
																					-- grasped by the external memory controller
										  
										  StateWaitForNextTimeWindow 				-- It waits for next time window to be requested
																					-- by the control unit										  
										  );

	type TypeStateGetTimeWindow is (StateInit,

									StateReadByteWf,										-- It signals the extenrnal
																										-- memory controller the start
																										-- of data read
									
									StateWaitRequest,											-- It waits for external memory
																										-- controller to signal
																										-- data available in data bus
									
									StateReadByte,									-- It reads data from external
																										-- memory controller
																										-- data bus into internal buffer
									
									StateLoop	-- It waits for data addressed
																										-- by externalMemoryAddress signal
																										-- to be output to the read data bus
																										
									);


	signal stateTimeWindowBuffer 		: TypeStateTimeWindowBuffer;
	signal stateGenerateNextAddress 	: TypeStateGenerateNextAddress;
	signal stateGetTimeWindow 		 	: TypeStateGetTimeWindow;

	signal writeTimeWindowBuffer 			: std_logic_vector(PARALLELISM_DEPTH-1 downto 0);
		 
	signal dataToTimeWindowBuffer 			: std_logic_vector(N_BITS_DATA-1 downto 0);
	signal timeWindowBufferWriteAddress 	: std_logic_vector(N_BITS_TIME_WINDOW downto 0);

	signal addressGraspedByExternalRamControllerStage1 	: std_logic;
	signal addressGraspedByExternalRamControllerStage2 	: std_logic;
	signal externalMemoryBusyStage1 					: std_logic;
	signal externalMemoryBusyStage2 					: std_logic;

	signal enableGenerateNextAddressesProcess 			: std_logic;
	signal processGenerateNextBurstAddressRunning 		: std_logic;
	signal enableProcessGetTimeWindow 					: std_logic;
	signal processGetTimeWindowIsRunning 				: std_logic;

	signal pixelAddressInExternalMemory 				: std_logic_vector(NbitsOfExternalMemoryAddress downto 0);

	signal readTimeWindowPulseCounter 					: natural;
	signal timeWindowCounter 							: natural;

	signal localNextAddress		 						: std_logic_vector(NbitsOfExternalMemoryAddress-1 downto 0);
	


	signal datacounter : natural;
	signal write_mem: std_logic;
	signal bc: natural;
	
begin  -- architecture bhv



--!@brief This is the implementation of:
--! \image html doc/ac_frame_buffer.png

buffers: for ii in 0 to PARALLELISM_DEPTH-1 generate
	--RAM
alt3pram_component_ii : alt3pram
	GENERIC MAP (
		indata_aclr => "OFF",
		indata_reg => "INCLOCK",
		intended_device_family => "Cyclone",
		lpm_type => "alt3pram",
		--ram_block_type => "M4K",
		outdata_aclr_a => "OFF",
		outdata_aclr_b => "OFF",
		outdata_reg_a => "OUTCLOCK",
		outdata_reg_b => "OUTCLOCK",
		rdaddress_aclr_a => "OFF",
		rdaddress_aclr_b => "OFF",
		rdaddress_reg_a => "INCLOCK",
		rdaddress_reg_b => "INCLOCK",
		rdcontrol_aclr_a => "OFF",
		rdcontrol_aclr_b => "OFF",
		rdcontrol_reg_a => "UNREGISTERED",
		rdcontrol_reg_b => "UNREGISTERED",
		width => N_BITS_DATA,
		widthad => N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH,
		write_aclr => "OFF",
		write_reg => "INCLOCK"
	)
	PORT MAP (
		outclock => clk,
		wren => writeTimeWindowBuffer(ii),
		inclock => clk,
		data => dataToTimeWindowBuffer,
		rdaddress_a => readAddressA(ii)((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH)-1 downto 0),
		wraddress => timeWindowBufferWriteAddress((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH)-1 downto 0),
		rdaddress_b => readAddressB(ii)((N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH)-1 downto 0),
		qa => dataOutA(ii)(N_BITS_DATA-1 downto 0),
		qb => dataOutB(ii)(N_BITS_DATA-1 downto 0)
		);

end generate buffers;
		 
zeroOutNonUsedDataOuts: for ii in PARALLELISM_DEPTH to ConstMaxParallelismDepth-1 generate
	dataOutA(ii) <= (others => '0');
	dataOutB(ii) <= (others => '0');
end generate zeroOutNonUsedDataOuts;	
		 
		 

--!@brief This process communicates with autocorrelation's control unit and
--!controls the other processes of this module
						
procTimeWindowBuffer: process (clk, rst_n) is
begin  -- process procTimeWindowBuffer
	if (rst_n = '0') then
		enableGenerateNextAddressesProcess <= '0';
		frameBufferReady <= '0';
		timeWindowReady <= '0';
		stateTimeWindowBuffer <= StateInit;
	elsif (clk'event and clk = '1') then

		externalMemoryBusyStage1 <= memoryDataReady;
		externalMemoryBusyStage2 <= externalMemoryBusyStage1;
		
		case stateTimeWindowBuffer is
			when StateInit =>
				frameBufferReady <= '0';
				timeWindowReady <= '0';
				enableGenerateNextAddressesProcess <= '0';
				if (externalMemoryBusyStage2 = '0') then
					stateTimeWindowBuffer <= StateWriteSensorFramesToExternalMemory;
				end if;
			when StateWriteSensorFramesToExternalMemory =>
				stateTimeWindowBuffer <= StateWaitForTimeWindowRequest;
			when StateWaitForTimeWindowRequest =>
				frameBufferReady <= '1';
				if (getNextTimeWindow = '1') then
					timeWindowReady <= '0';
					stateTimeWindowBuffer <= StateStartGetTimeWindowProcess;
				end if;
			when StateStartGetTimeWindowProcess =>
				stateTimeWindowBuffer <= StateGettingTimeWindow;
			when StateGettingTimeWindow =>
				if (processGetTimeWindowIsRunning = '0') then
					timeWindowReady <= '1';
					stateTimeWindowBuffer <= StateWaitForTimeWindowRequest;
				end if;
			when others =>
				stateTimeWindowBuffer <= StateInit;
		end case;
		
	end if;
end process procTimeWindowBuffer;  

enableProcessGetTimeWindow <= '1' when (stateTimeWindowBuffer = StateStartGetTimeWindowProcess or
										(processGetTimeWindowIsRunning = '1' and stateTimeWindowBuffer = StateGettingTimeWindow)) else '0';
  
  


--!@brief This process inplements the communication with the read interface
--! of the external memory controller according to:
--! \image html doc/diagram-external-memory-controller-read-data-interface.png
--!
--! Before start reading data through the read interface via
--! externalMemoryAddress signal, 2 prefetch addresses must be issued to the EMC,
--! so it might cache 2 bursts of data;
--! Whenever the EMC signals that the prefetch address has been grasped via
--! addressGraspedByExternalRamController signal, a new prefetch address must be
--! issued to the EMC soon after;

procGetTimeWindow: process (clk, rst_n) is
begin  -- process procGetTimeWindow
	if (rst_n = '0') then
		timeWindowBufferWriteAddress <= (others => '0');
		stateGetTimeWindow <= StateInit;
		bc <= 0;
	elsif (clk'event and clk = '1') then

		case stateGetTimeWindow is
			when StateInit =>
				timeWindowBufferWriteAddress <= (others => '0');
				localNextAddress(1 downto 0) <= (others => '0');
				localNextAddress(N_BITS_FRAME_SIZE-1 downto 2) <= pixelIndex(N_BITS_FRAME_SIZE-1 downto 2); -- & "00";
				localNextAddress(NbitsOfExternalMemoryAddress-1 downto N_BITS_FRAME_SIZE) <= (others => '0');
				if enableProcessGetTimeWindow = '1' then
					stateGetTimeWindow <= StateReadByteWf;
				end if;
			when StateReadByteWf =>
				acMasterRead <= '1';
				stateGetTimeWindow <= StateWaitRequest;
			when StateWaitRequest =>
				if (acMasterWaitRequest = '0') then
					acMasterRead <= '0';
					stateGetTimeWindow <= StateReadByte;
					bc <= 0;
				end if;
			when StateReadByte =>
				if (acMasterReadDataValid = '1') then
					if (bc = 3) then
						bc <= 0;
						timeWindowBufferWriteAddress <= timeWindowBufferWriteAddress + 1;
						stateGetTimeWindow <= StateLoop;
					else
						bc <= bc + 1;
					end if;
				end if;
			when StateLoop =>
				if ( timeWindowBufferWriteAddress = std_logic_vector(to_unsigned(W, timeWindowBufferWriteAddress'length)) ) then
					stateGetTimeWindow <= StateInit;
				else
					localNextAddress <= localNextAddress + FRAME_SIZE;
					stateGetTimeWindow  <= StateReadByteWf;
				end if;
			when others =>
				stateGetTimeWindow <= StateInit;
		end case;
	end if;
				
end process procGetTimeWindow;

processGetTimeWindowIsRunning <= '1' when (stateGetTimeWindow /= StateInit) else '0';



--------------------------------------------------------------------
------------------  Output signals ---------------------------------
--------------------------------------------------------------------


--! @brief Every sub-buffer of frame buffer has its own write enable;
--! Therefore, the one whose address span contains the current address of
--! timeWindowBufferWriteAddress must be enabled;
--! The address span of a sub-buffer is the address range that address the
--! sub-buffer considering the sub-buffer a part of the whole internal buffer
--! which has a single memory map for writing 
generateWriteTimeWindowBuffer: for ii in 0 to PARALLELISM_DEPTH-1 generate

	writeTimeWindowBuffer(ii) <= '1' when ( ( timeWindowBufferWriteAddress((N_BITS_TIME_WINDOW-1) downto (N_BITS_TIME_WINDOW-N_BITS_PARALLELISM_DEPTH)) = std_logic_vector(to_unsigned(ii, N_BITS_PARALLELISM_DEPTH)) ) and
										   (acMasterReadDataValid = '1' and bc = (3 - unsigned(pixelIndex(1 downto 0)))) ) else '0';

end generate generateWriteTimeWindowBuffer;


dataToTimeWindowBuffer <= acMasterReadData; 

acMasterAddress <= x"38000000" + localNextAddress; -- + x"00000001";							   
acMasterBurstCount <= "0100"; --'1';

end architecture bhv;
