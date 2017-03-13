library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bridge_stSrc_mmMaster is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    NBITS_ADDR : integer := 20;
    NBITS_DATA : integer := 8;
    NBITS_BURST : integer := 4;
    BASE_ADDRESS : unsigned(31 downto 0) := x"38000000"
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
    
    -- avalon MM Master    
    master_waitrequest : in std_logic;
    master_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    master_burstcount  : out std_logic_vector(NBITS_BURST-1 downto 0);
    master_write       : out std_logic;
    master_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    
    -- avalon ST Sink
    st_startofpacket : in std_logic;
    st_endofpacket   : in std_logic;
    st_datain        : in std_logic_vector(NBITS_DATA-1 downto 0);
    st_datavalid     : in std_logic;
    st_ready         : out std_logic
    
    );               

end entity bridge_stSrc_mmMaster;

architecture bhv of bridge_stSrc_mmMaster is

begin  -- architecture bhv

  

end architecture bhv;
