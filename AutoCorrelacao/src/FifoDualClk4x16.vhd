library IEEE;
library work;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.all;

entity FifoDualClk4x16 is
	port(
		ClkInsert, ClkRemove: 	in STD_LOGIC;
		Insert, Remove, Reset:			in STD_LOGIC;
		DataInsert: 			in STD_LOGIC_VECTOR(15 downto 0);

		RemovedData: 			out STD_LOGIC_VECTOR(15 downto 0);
		probe: 			out STD_LOGIC_VECTOR(15 downto 0);
---		probe2: 			out STD_LOGIC_VECTOR(8 downto 0);
		nearFull : 		out STD_LOGIC;
		Full: 			out STD_LOGIC
	);
end entity FifoDualClk4x16;

architecture Impl1 of FifoDualClk4x16 is

	component Ram4x16 is
		port
		(
			data		: in STD_LOGIC_VECTOR (15 downto 0);
			rdaddress		: in STD_LOGIC_VECTOR (1 downto 0);
			rdclock		: in STD_LOGIC ;
			wraddress		: in STD_LOGIC_VECTOR (1 downto 0);
			wrclock		: in STD_LOGIC ;
			wren		: in STD_LOGIC  := '1';
			q		: out STD_LOGIC_VECTOR (15 downto 0)
		);
	end component Ram4x16;

	signal fifoCount: STD_LOGIC_VECTOR(9 downto 0);
	signal fifoCountIns, fifoCountRem: STD_LOGIC_VECTOR(9 downto 0);
	signal nextMsb, nextLsb : STD_LOGIC_VECTOR(7 downto 0);
	signal addrInsert, nextAddr, nextIncAddr, addrRemove, memAddrRemove, addrWrite: STD_LOGIC_VECTOR(1 downto 0);
	signal intRemovedData, regIntRemovedData, intDataInsert, fake_data: STD_LOGIC_VECTOR(15 downto 0);
	signal intEmpty, intFull, wr, removeId, inc, dec, incClkIns, incClkRem, 
		incClkIns2, intPreEmpty, localClkRemove, intInsert, BufferIndexRem,
		BufferIndexRemStage1, BufferIndexIns: STD_LOGIC;
			
begin
--	localClkRemove <= not (ClkRemove and Remove);

	memAddrRemove <= nextAddr when (Remove = '1') else addrRemove;	
	MEM: Ram4x16 port map(DataInsert, memAddrRemove, ClkRemove, addrInsert, ClkInsert, wr, RemovedData);
        fake_data <= nextMsb & nextLsb;
	
	FIFO_INSERT: process(ClkInsert, Insert, intInsert, intFull, addrInsert, Reset)
	begin
		if (Reset = '0') then
			addrInsert <= "00";
                        nextMsb <= (others => '0');
                        nextLsb <= (others => '0');
		elsif (ClkInsert'event and ClkInsert = '1') then
			if (Insert = '1') then -- and intFull = '0') then
                                nextMsb <= nextMsb + 2;
                                nextLsb <= nextLsb + 1;
				addrInsert <= addrInsert + "01";
			else
				addrInsert <= addrInsert;
			end if;
		end if;
	end process FIFO_INSERT;
	
	nextIncAddr <= addrRemove + "01";
	nextAddr <= nextIncAddr;
	FIFO_REMOVE: process(ClkRemove, Remove, intEmpty, nextAddr, Reset)
	begin
		if (Reset = '0') then
			addrRemove <= "00";
		elsif (ClkRemove'event and ClkRemove = '1') then
			if (Remove = '1') then -- and intEmpty = '0') then
				addrRemove <= nextAddr;
			else
				addrRemove <= addrRemove;
			end if;
		end if;
	end process FIFO_REMOVE;

	REG_CLKINS: block(ClkInsert'event and ClkInsert = '1')
	begin
		BufferIndexRemStage1 <= guarded addrRemove(1);
		BufferIndexRem <= guarded BufferIndexRemStage1;
	end block REG_CLKINS;
	BufferIndexIns <= addrInsert(1);
	wr <= '1' when (Insert = '1') else '0';

	Full <= '1' when (BufferIndexRem = BufferIndexIns) else  '0';
	nearFull <= addrInsert(0);
	

end Impl1;
