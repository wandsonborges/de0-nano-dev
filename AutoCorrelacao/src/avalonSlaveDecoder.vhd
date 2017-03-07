library IEEE;
library work;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


entity avalonControlSlaveDecoder is
	
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

		busy    					  		: in std_logic; 			--! '1' signals autocorrelation being processed

		acCorrelationBufferData				: in std_logic_vector(31 downto 0); --(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0);



		--Outputs

		--Avalon slave output: control
		acSlaveWaitRequest 					: out std_logic;
		acSlaveReadDataValid 				: out std_logic;
		acSlaveReadData						: out std_logic_vector(31 downto 0); --(N_BITS_PXL_AC_RESULT_TOTAL-1 downto 0); 	--! Data read from external memory

		vaiAutocorrelation 			 		: out std_logic; 									--! it fires autocorrelation

		acCorrelationBufferAddr 		 	: out std_logic_vector(N_BITS_TIME_WINDOW-1 downto 0)
		);

end entity avalonControlSlaveDecoder;



 architecture arch of  avalonControlSlaveDecoder is

 	type TSTATE is (START, READING, READING_DATA, WAITON_AC);
	
 	signal control: std_logic_vector(31 downto 0); --(NbitsOfExternalMemoryAddress-1 downto 0) := (others => '0');
 	signal status: std_logic_vector(31 downto 0); --(NbitsOfExternalMemoryAddress-1 downto 0) := (others => '0');

 	signal state: TSTATE;

 	signal latencyCounter 		: natural;
	
	
 begin
 	proc: process (clk, nrst) is
 	begin  -- process procWrite
 		if nrst = '0' then  			-- asynchronous reset (active low)
 			control <= (others => '0');
 			latencyCounter <= 0;
 			state <= START;
 			acSlaveReadDataValid <= '0';
 			acSlaveReadData <= (others => '0');
 		elsif clk'event and clk = '1' then  -- rising clock edge
 			if (busy = '1') then
 				control(0) <= '0';
 			end if;
 			case state is
 				when START =>
 					latencyCounter <= 0;
 					if (acSlaveRead = '1') then
 						if (unsigned(acSlaveAddress) >= W/4) then
 							acSlaveReadDataValid <= '1';
 							if (unsigned(acSlaveAddress) = W/4) then
 								acSlaveReadData <= control;
 							else
 								acSlaveReadData <= status;
 							end if;
 							state <= START;
 						else
 							-- if (busy = '1') then
 							-- 	state <= WAITON_AC;
 							-- else
 							-- 	state <= READING_DATA;
 							-- end if;
							acSlaveReadDataValid <= '0';
							 acSlaveReadData <= (others => '0');
							 latencyCounter <= 0;
 							state <= READING_DATA;
 						end if;
 					elsif (chipselect = '1' and acSlaveWrite = '1') then
 						if (unsigned(acSlaveAddress) = W/4) then
 							-- if (busy = '0') then
 							-- 	control <= acSlaveWriteData;
 							-- end if;
 							control <= acSlaveWriteData;
 						end if;
 						acSlaveReadDataValid <= '0';
 						acSlaveReadData <= (others => '0');
 						state <= START;
 					else
 						acSlaveReadDataValid <= '0';
 						acSlaveReadData <= (others => '0');
 						state <= START;
 					end if;
 				when READING =>
 					-- if (acSlaveWrite = '0' and acSlaveRead = '0') then
 					-- 	state <= START;
 					-- end if;
 					acSlaveReadDataValid <= '0';
 					acSlaveReadData <= (others => '0');
 					state <= START;
 				when READING_DATA 	=>
 					if (latencyCounter = 2)  then
 						latencyCounter <= 0;
 						acSlaveReadDataValid <= '1';
 						acSlaveReadData <= acCorrelationBufferData;
 						state <= START;
 					else
						acSlaveReadDataValid <= '0';
						acSlaveReadData <= (others => '0');
 						latencyCounter <= latencyCounter + 1;
 					end if;
 				-- when WAITON_AC =>
 				-- 	if (busy = '0') then
 				-- 		state <= READING_DATA;
 				-- 	end if;
 				when others =>
 					state <= START;
 			end case;
 		end if;
 	end process proc;



 	-- acSlaveReadData <= control  when (unsigned(acSlaveAddress) = W) else
 	-- 				   status when (unsigned(acSlaveAddress) = (W+1)) else
 	-- 				   acCorrelationBufferData;
								   
 	acSlaveWaitRequest <= '0'; -- '1' when ((state = READING and acSlaveWrite = '1') or
 	-- 								(state = START and acSlaveRead = '1' and acSlaveWrite = '1') or
 	-- 								(state = START and busy = '1') or
 	-- 								(state = WAITON_AC)) else '0';
	
 	--acSlaveReadDataValid <= '1' when (state = READING and acSlaveWrite = '0' and acSlaveRead = '0') else '0';

 	vaiAutocorrelation <= control(0);
	status(0) <= busy;
	--status <= x"c0a8335f";

 	acCorrelationBufferAddr <= acSlaveAddress(N_BITS_TIME_WINDOW-1 downto 0);

 end architecture arch;




-- architecture bhv of avalonControlSlaveDecoder is

--  --Internal RAM
--  type ram_type is array (0 to 3) of std_logic_vector(31 downto 0);
--  signal registers : ram_type := (
--    x"00000005",
--    x"00000015",
--    x"00000025",
--    x"00000035"
--    );
  
--  signal stall_transfer : std_logic := '0';
--  signal store_addr, read_addr : std_logic := '0';
--  signal fifo_words : std_logic_vector(3 downto 0) := (others => '0');
--  signal half_full : std_logic := '0';
--  signal fifo_empty, fifo_full : std_logic := '0';

--  signal s_readdata : std_logic_vector(31 downto 0) := (others => '0');
--  signal s_readdatavalid, s_readdatavalid_ff : std_logic := '0';
--  signal s_addr : std_logic_vector(31 downto 0);
 
-- begin  -- architecture bhv

-- half_full <= fifo_words(3);
-- stall_transfer <= half_full;

-- read_req_proc: process (clk, nrst) is
-- begin  -- process read_req_proc
-- 	if nrst = '0' and chipselect = '0' then                   -- asynchronous reset (active low)
-- 		acSlaveReadDataValid <= '0';
-- 		acSlaveReadData <= (others => '0');
-- 	elsif clk'event and clk = '1' then    -- rising clock edge
-- 		--if (chipselect = '1') then
-- 			if (acSlaveRead = '1') then -- and chipselect = '1') then
-- 				acSlaveReadData <= registers(to_integer(unsigned(acSlaveAddress)));
-- 				acSlaveReadDataValid <= '1';
-- 			-- elsif (chipselect = '1' and acSlaveWrite = '1' and unsigned(acSlaveAddress) < 4) then
-- 			-- 	registers(to_integer(unsigned(acSlaveAddress))) <= acSlaveWriteData;
-- 			else
-- 				acSlaveReadDataValid <= '0';
-- 				acSlaveReadData <= (others => '0');
-- 			end if;
-- 		--end if;
		
-- 	end if;
-- end process read_req_proc;


-- write_req_proc: process (clk, nrst) is
-- begin  -- process read_req_proc
-- 	--if nrst = '0' then                   -- asynchronous reset (active low)
-- 	if clk'event and clk = '1' then    -- rising clock edge
-- 		--if (chipselect = '1') then
-- 			if (chipselect = '1' and acSlaveWrite = '1' and unsigned(acSlaveAddress) < 4) then
-- 				registers(to_integer(unsigned(acSlaveAddress))) <= acSlaveWriteData;
-- 			end if;
-- 		--end if;
		
-- 	end if;
-- end process write_req_proc;

-- acSlaveWaitRequest <= '0';

-- vaiAutocorrelation <= '0';
-- acCorrelationBufferAddr <= (others => '0');
  
-- end architecture bhv;
