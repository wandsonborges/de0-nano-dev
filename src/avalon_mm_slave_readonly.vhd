library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity avalon_mm_slave_readonly is
  
  generic (
    ADDR_W  : integer := 2;
    DATA_W  : integer := 32;
    BURST_W : integer := 8;
    BURST   : integer := 8;
    BYTE_EN_W : integer := 4
    );

  port (
    clk, rst      : in  std_logic;
    waitrequest   : out std_logic;
    chipselect    : in  std_logic;
    address       : in  std_logic_vector(ADDR_W-1 downto 0);
    read          : in  std_logic;
    readdatavalid : out std_logic;
    readdata      : out std_logic_vector(DATA_W-1 downto 0);
    byteenable    : in  std_logic_vector(BYTE_EN_W-1 downto 0)    
    );

end entity avalon_mm_slave_readonly;

architecture bhv of avalon_mm_slave_readonly is

  --Internal RAM
  type ram_type is array (0 to (2**ADDR_W)-1) of std_logic_vector(DATA_W-1 downto 0);
  signal registers : ram_type := (
    x"00000005",
    x"00000015",
    x"00000025",
    x"00000035"
    );
  

begin  -- architecture bhv



read_req_proc: process (clk, rst) is
begin  -- process read_req_proc
  if rst = '1' then                   -- asynchronous reset (active low)
    readdatavalid <= '0';
    readdata <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    if (read = '1' and chipselect = '1') then
      readdata <= registers(to_integer(unsigned(address)));
      readdatavalid <= '1';                            
    else
      readdatavalid <= '0';
      readdata <= (others => '0');
    end if;

    waitrequest <= '0';
    
  end if;
end process read_req_proc;



  
end architecture bhv;
