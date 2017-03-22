library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;


ENTITY Reset_Delay IS
	port 
	(
		iCLK		:	 IN STD_LOGIC;
		iRST		:	 IN STD_LOGIC;
		oRST_0		:	 OUT STD_LOGIC;
		oRST_1		:	 OUT STD_LOGIC;
		oRST_2		:	 OUT STD_LOGIC;
		oRST_3		:	 OUT STD_LOGIC;
		oRST_4		:	 OUT STD_LOGIC
	);
END entity Reset_Delay;
architecture bhv of Reset_Delay is

  signal Cont : unsigned(31 downto 0) := (others => '0');
  
begin  -- architecture bhv
proc: process (iCLK, iRST) is
begin  -- process proc
  if iRST = '0' then                    -- asynchronous reset (active low)
    Cont <= (others => '0');
    oRST_0 <= '0';
    oRST_1 <= '0';
    oRST_2 <= '0';
    oRST_3 <= '0';
    oRST_4 <= '0';    
  elsif iCLK'event and iCLK = '1' then  -- rising clock edge
    if (Cont /= x"02FFFFFF") then
      Cont <= Cont + 1;
    end if;
    if (Cont >= x"001FFFFF") then
      oRST_0 <= '1';
    end if;
    if (Cont >= x"002FFFFF") then
      oRST_1 <= '1';
    end if;
    if (Cont >= x"00EFFFFF") then
      oRST_2 <= '1';
    end if;
    if (Cont >= x"01FFFF00") then
      oRST_3 <= '1';
    end if;
    if (Cont >= x"01FFFFFF") then
      oRST_4 <= '1';
    end if;
    
          
  end if;
end process proc;
  

end architecture bhv;
