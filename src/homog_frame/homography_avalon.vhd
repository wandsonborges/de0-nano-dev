library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity homography_avalon is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    HOMOG_BITS_INT : integer := 12;
    HOMOG_BITS_FRAC : integer := 20;
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 8;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8;
    CICLOS_LATENCIA : integer := 8;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 256
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Homography Image
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    --masterwr_burstcount  : out std_logic_vector(NBITS_BURST-1 downto 0);
    

    -- avalon MM Master 2 - Get Raw Image
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic;
    
    -- avalon MM Slave - Configure Homography Matrix
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(3 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0)    
    );               

end entity homography_avalon;

architecture bhv of homography_avalon is

  signal enable_read            : std_logic;
  signal packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal get_read_data          : std_logic;
  signal data_ready             : std_logic;
  signal data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal burst_en               : std_logic;

  --CONTROL SIGNAL
  signal rdreq, start_op, start_op_f : std_logic := '0';
  signal vectorSize : std_logic_vector(31 downto 0);
  
    -- BUFFER ADDR:
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38C00000";

    -- CONFIGURE HOMOG VECTOR HW SIGNALS
  type reg_type is array (0 to 5) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223355", --id
    x"00000000", --vectorSize
    x"00000000", --start
    ADDR_BASE_READ, --input pointer
    ADDR_BASE_WRITE, -- output pointer
    x"00000000" --busy
    );
  signal registers : reg_type := init_registers;

    --GENERAL SIGNALS
  signal wrcount : UNSIGNED(31 downto 0) := (others => '0');
      -- AVALON SIGNALS
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_WRITE;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

begin  -- architecture bhv


-- AVALON SLAVE: ADD VECTOR HW CONF
 rd_wr_slave_proc: process (clk, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      registers <= init_registers;
    elsif clk'event and clk = '1' then  -- rising clock edge     
      --LEITURA DO SLAVE  ---- READ PROC
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
      --ESCRITA NO SLAVE
      elsif slave_write = '1'  then
        if unsigned(slave_address) > 0 then 
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
      end if;

      if wrcount > 0 then
        registers(5)(0) <= '1';
      else
        registers(5)(0) <= '0';
      end if;
      
    end if;
  end process rd_wr_slave_proc;

  vectorSize <= registers(1);
  start_op <= registers(2)(0);

  
  readPacketsAvalon_1: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR      => NBITS_ADDR,
      NBITS_DATA      => NBITS_DATA,
      NBITS_COLS      => NBITS_COLS,
      NBITS_LINES     => NBITS_LINES,
      CICLOS_LATENCIA => CICLOS_LATENCIA,
      COLS            => COLS,
      LINES           => LINES,
      NBITS_PACKETS   => NBITS_PACKETS,
      FIFO_SIZE       => FIFO_SIZE,
      BURST           => BURST)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_waitrequest   => masterrd_waitrequest,
      masterrd_readdatavalid => masterrd_readdatavalid,
      masterrd_readdata      => masterrd_readdata,
      masterrd_address       => masterrd_address,
      masterrd_read          => masterrd_read,
      enable_read            => enable_read,
      packets_to_read        => packets_to_read,
      address_init           => address_init,
      get_read_data          => rdreq,
      data_ready             => data_ready,
      data_out               => data_out,
      burst_en               => burst_en);

  address_init <= registers(3);
  enable_read <= start_op;
  packets_to_read <= vectorSize;

------ RESULT WRITE PROCESS  
  s_masterwrite <= data_ready;
  masterwr_write <= s_masterwrite;
  masterwr_address <= std_logic_vector(unsigned(registers(4)) + wrcount);
  masterwr_writedata <= std_logic_vector(unsigned(data_out));
  rdreq <= (not masterwr_waitrequest) and s_masterwrite;
  --masterwr_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));
    
  wrcountProc: process (clk, rst_n) is
  begin  -- process wrcount
    if rst_n = '0' then                 -- asynchronous reset (active low)
      wrcount <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if rdreq = '1' then
        if wrcount = unsigned(vectorSize)-1 then
          wrcount <= (others => '0');
        else          
          wrcount <= wrcount + 1;
        end if;
      else
        wrcount <= wrcount;
      end if;      
    end if;
  end process wrcountProc;

  
  
end architecture bhv;
