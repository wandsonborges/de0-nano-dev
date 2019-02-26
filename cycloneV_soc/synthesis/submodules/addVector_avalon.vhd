library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity addVector_avalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 1024;
    FIFO_SIZE_BITS : integer := 10;
    NBITS_DATA : integer := 32;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8;
    ADDR_READ1 : std_logic_vector(31 downto 0) := x"38000000";
    ADDR_READ2 : std_logic_vector(31 downto 0) := x"38100000";
    ADDR_WRITE : std_logic_vector(31 downto 0) := x"38200000"
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Add Vector Result
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    

    -- avalon MM Master 2 - Get Header and Vector 1
    masterrd1_waitrequest : in std_logic;
    masterrd1_readdatavalid : in std_logic;
    masterrd1_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd1_burstcount   : out std_logic_vector(3 downto 0);
    masterrd1_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd1_read       : out std_logic;

    -- avalon MM Master 2 - Get Vector 2
    masterrd2_waitrequest : in std_logic;
    masterrd2_readdatavalid : in std_logic;
    masterrd2_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd2_burstcount   : out std_logic_vector(3 downto 0);
    masterrd2_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd2_read       : out std_logic;
    
    -- avalon MM Slave - Configure addVector Hardware
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(2 downto 0);
    slave_byteenable    : in std_logic_vector(NBITS_BYTEEN-1 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0)
    
    
    );               

end entity addVector_avalon;

architecture bhv of addVector_avalon is

  signal v1_masterrd_waitrequest   : std_logic;
  signal v1_masterrd_readdatavalid : std_logic;
  signal v1_masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v1_masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v1_masterrd_read          : std_logic;
  signal v1_enable_read            : std_logic;
  signal v1_packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal v1_address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v1_get_read_data          : std_logic;
  signal v1_data_ready             : std_logic;
  signal v1_data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v1_burst_en               : std_logic;
  signal v1_masterrd_burstcount    : std_logic_vector(3 downto 0);


  signal v2_masterrd_waitrequest   : std_logic;
  signal v2_masterrd_readdatavalid : std_logic;
  signal v2_masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v2_masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v2_masterrd_read          : std_logic;
  signal v2_enable_read            : std_logic;
  signal v2_packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal v2_address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v2_get_read_data          : std_logic;
  signal v2_data_ready             : std_logic;
  signal v2_data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v2_burst_en               : std_logic;
  signal v2_masterrd_burstcount    : std_logic_vector(3 downto 0);

  
  -- BUFFER ADDR:
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_READ1;
  constant ADDR_BASE_READ2 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_READ2;
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_WRITE;



  --GENERAL SIGNALS
  signal wrcount : UNSIGNED(31 downto 0) := (others => '0');

  --CONTROL SIGNAL
  signal rdreq, start_op, start_op_f : std_logic := '0';

  signal vectorSize : std_logic_vector(31 downto 0);
  
  -- CONFIGURE ADD VECTOR HW SIGNALS
  type reg_type is array (0 to 6) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223344", --id
    x"00005000", --vectorSize
    x"00000001", --start
    ADDR_BASE_READ, --addr vector 1
    ADDR_BASE_READ2, --addr vector 2
    ADDR_BASE_WRITE, -- addr vector result
    x"00000000" --busy
    );
  signal registers : reg_type := init_registers;

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
        registers(6)(0) <= '1';
      else
        registers(6)(0) <= '0';
      end if;
      
    end if;
  end process rd_wr_slave_proc;

  vectorSize <= registers(1);
  start_op <= registers(2)(0);

  readPacketsAvalon_1: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE,
      FIFO_SIZE_BITS => FIFO_SIZE_BITS)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_waitrequest   => v1_masterrd_waitrequest,
      masterrd_readdatavalid => v1_masterrd_readdatavalid,
      masterrd_readdata      => v1_masterrd_readdata,
      masterrd_address       => v1_masterrd_address,
      masterrd_read          => v1_masterrd_read,
      masterrd_burstcount    => v1_masterrd_burstcount,
      enable_read            => v1_enable_read,
      packets_to_read        => v1_packets_to_read,
      address_init           => v1_address_init,
      get_read_data          => v1_get_read_data,
      data_ready             => v1_data_ready,
      burst_en               => v1_burst_en,
      data_out               => v1_data_out);


      masterrd1_burstcount <= v1_masterrd_burstcount; 
      v1_masterrd_waitrequest <= masterrd1_waitrequest;
      v1_masterrd_readdatavalid <= masterrd1_readdatavalid;
      v1_masterrd_readdata <= masterrd1_readdata; 
      masterrd1_address <= v1_masterrd_address;
      masterrd1_read <= v1_masterrd_read; 
      v1_enable_read <= start_op; 
      v1_packets_to_read <= vectorSize;
      v1_address_init <= registers(3); --std_logic_vector(unsigned(ADDR_BASE_READ));
  

  readPacketsAvalon_2: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE,
      FIFO_SIZE_BITS => FIFO_SIZE_BITS)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_waitrequest   => v2_masterrd_waitrequest,
      masterrd_readdatavalid => v2_masterrd_readdatavalid,
      masterrd_readdata      => v2_masterrd_readdata,
      masterrd_address       => v2_masterrd_address,
      masterrd_read          => v2_masterrd_read,
      masterrd_burstcount    => v2_masterrd_burstcount,
      enable_read            => v2_enable_read,
      packets_to_read        => v2_packets_to_read,
      address_init           => v2_address_init,
      get_read_data          => v2_get_read_data,
      data_ready             => v2_data_ready,
      burst_en               => v2_burst_en,
      data_out               => v2_data_out);

      masterrd2_burstcount <= v2_masterrd_burstcount; 
      v2_masterrd_waitrequest <= masterrd2_waitrequest;
      v2_masterrd_readdatavalid <= masterrd2_readdatavalid;
      v2_masterrd_readdata <= masterrd2_readdata; 
      masterrd2_address <= v2_masterrd_address;
      masterrd2_read <= v2_masterrd_read;
      v2_enable_read <= start_op; 
      v2_packets_to_read <= vectorSize;
      v2_address_init <= registers(4); --std_logic_vector(unsigned(ADDR_BASE_READ)+(unsigned(vectorSize) sll 2));



------ RESULT WRITE PROCESS  
  s_masterwrite <= v1_data_ready and v2_data_ready;
  masterwr_write <= s_masterwrite;
  masterwr_address <= std_logic_vector(unsigned(registers(5)) + (wrcount sll 2));
  masterwr_writedata <= std_logic_vector(unsigned(v1_data_out) + unsigned(v2_data_out));
  rdreq <= (not masterwr_waitrequest) and s_masterwrite;
  v1_get_read_data <= rdreq;
  v2_get_read_data <= rdreq;


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
