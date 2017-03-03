library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avalon_mm_master_writer is
  
  generic (
    ADDR_W  : integer := 32;
    DATA_W  : integer := 32;
    BURST_W : integer := 8;
    BURST   : integer := 8;
    BYTE_EN_W : integer := 4
    );

  port (
    clk, rst     : in  std_logic;
    waitrequest  : in  std_logic;
    address      : out std_logic_vector(ADDR_W-1 downto 0);
    write        : out std_logic;
    writedata    : out std_logic_vector(DATA_W-1 downto 0);
    burstcount   : out std_logic_vector(BURST_W-1 downto 0);
    byteenable   : out std_logic_vector(BYTE_EN_W-1 downto 0)    
    );

end entity avalon_mm_master_writer;

architecture bhv of avalon_mm_master_writer is

  constant MAX_BURST_TO_WRITE : integer := 256;
  
  signal stall_transfer : std_logic := '0';
  signal s_writedata : unsigned(DATA_W-1 downto 0) := (others => '0');
  signal s_write : std_logic := '0';
  signal s_address : unsigned(ADDR_W-1 downto 0) := resize(x"38000000", ADDR_W);

  signal words_written_during_burst : unsigned(BURST_W-1 downto 0) := (others => '0');
  signal bursts_written : unsigned(10 downto 0) := (others => '0');
  
begin  -- architecture bhv

  burst_write_proc: process (clk, rst) is
  begin  -- process burst_write_proc
    if rst = '1' then                   -- asynchronous reset (active low)
      s_write <= '0';
      s_writedata <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (stall_transfer = '1') then
        s_write <= s_write;
        s_writedata <= s_writedata;
      elsif (bursts_written = MAX_BURST_TO_WRITE) then
        s_write <= '0';
        s_writedata <= (others => '0');
        --bursts_written <= (others => '0');
      elsif (words_written_during_burst = BURST) then
        s_write <= '0';
        words_written_during_burst <= (others => '0');
        bursts_written <= bursts_written + 1;
        s_address <= s_address + BURST*(ADDR_W/8);
      else
        s_write <= '1';
        words_written_during_burst <= words_written_during_burst + 1;
      end if;
      
      if (s_write = '1' and stall_transfer = '0') then
        s_writedata <= s_writedata + 1;
      end if;  
       
    end if;
    
  end process burst_write_proc;

  stall_transfer <= waitrequest;
  write <= s_write;
  writedata <= std_logic_vector(s_writedata);
  burstcount <= std_logic_vector(to_unsigned(BURST, BURST_W));
  byteenable <= (others => '1');
  address <= std_logic_vector(s_address);
  
end architecture bhv;
