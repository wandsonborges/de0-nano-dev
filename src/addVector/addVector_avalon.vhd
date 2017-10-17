library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity addVector_avalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 256;
    NBITS_DATA : integer := 32;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Add Vector Result
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    masterwr_burstcount  : out std_logic_vector(NBITS_BURST-1 downto 0);
    

    -- avalon MM Master 2 - Get Header and Vector 1
    masterrd1_waitrequest : in std_logic;
    masterrd1_readdatavalid : in std_logic;
    masterrd1_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd1_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd1_read       : out std_logic;

    -- avalon MM Master 2 - Get Vector 2 
    masterrd2_waitrequest : in std_logic;
    masterrd2_readdatavalid : in std_logic;
    masterrd2_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd2_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd2_read       : out std_logic;
    
    -- avalon MM Slave - Configure addVector Hardware
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(1 downto 0);
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

  
  -- BUFFER ADDR:
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";
  signal ADDR_BASE_READ_PARAM2 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_READ;
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38500000";



  --GENERAL SIGNALS
  signal rdcount : UNSIGNED(31 downto 0) := (others => '0');
  signal words_written_during_burst : UNSIGNED(NBITS_BURST-1 downto 0) := (others => '0');


  --CONTROL SIGNAL
  signal rdreq, start_op, start_op_f : std_logic := '0';


  --HEADER SIGNALS
  signal words2read : UNSIGNED(31 downto 0) := (others => '0');
  signal got_header_flag : std_logic := '0';

  
  -- CONFIGURE ADD VECTOR HW SIGNALS
  type reg_type is array (0 to 3) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223344", --id
    x"00000000", --start
    x"00000000", --busy
    x"00000000" --reserved
    );
  signal registers : reg_type := init_registers;

    --READ PARAMETER STATE MACHINE
  type read_control_st is (st_idle, st_extract_header, st_extract_data, st_finish);
  signal state_read : read_control_st := st_idle;

  --BURST WRITE SM
  type wr_control_st is (st_idle, st_write);
  signal state_write : wr_control_st := st_idle;

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
    elsif clk'event and clk = '1' then  -- rising clock edge     
      --LEITURA DO SLAVE  ---- READ PROC
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
      --ESCRITA NO SLAVE
      elsif slave_write = '1' and slave_chipselect = '1' then
        if unsigned(slave_address) > 1 then 
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
      end if;      
    end if;
  end process rd_wr_slave_proc;

  start_op <= registers(1)(0);


  readPacketsAvalon_1: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_waitrequest   => v1_masterrd_waitrequest,
      masterrd_readdatavalid => v1_masterrd_readdatavalid,
      masterrd_readdata      => v1_masterrd_readdata,
      masterrd_address       => v1_masterrd_address,
      masterrd_read          => v1_masterrd_read,
      enable_read            => v1_enable_read,
      packets_to_read        => v1_packets_to_read,
      address_init           => v1_address_init,
      get_read_data          => v1_get_read_data,
      data_ready             => v1_data_ready,
      burst_en               => v1_burst_en,
      data_out               => v1_data_out);

      v1_masterrd_waitrequest <= masterrd1_waitrequest;
      v1_masterrd_readdatavalid <= masterrd1_readdatavalid;
      v1_masterrd_readdata <= masterrd1_readdata; 
      masterrd1_address <= v1_masterrd_address when state_read = st_extract_data else ADDR_BASE_READ;
      masterrd1_read <= '1' when v1_masterrd_read = '1' or state_read = st_extract_header else '0';
      v1_enable_read <= '1' when state_read = st_extract_data;
      v1_packets_to_read <= std_logic_vector(words2read);
      v1_address_init <= std_logic_vector(unsigned(ADDR_BASE_READ)+1);
  

  readPacketsAvalon_2: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      masterrd_waitrequest   => v2_masterrd_waitrequest,
      masterrd_readdatavalid => v2_masterrd_readdatavalid,
      masterrd_readdata      => v2_masterrd_readdata,
      masterrd_address       => v2_masterrd_address,
      masterrd_read          => v2_masterrd_read,
      enable_read            => v2_enable_read,
      packets_to_read        => v2_packets_to_read,
      address_init           => v2_address_init,
      get_read_data          => v2_get_read_data,
      data_ready             => v2_data_ready,
      burst_en               => v2_burst_en,
      data_out               => v2_data_out);
  
      v2_masterrd_waitrequest <= masterrd2_waitrequest;
      v2_masterrd_readdatavalid <= masterrd2_readdatavalid;
      v2_masterrd_readdata <= masterrd2_readdata; 
      masterrd2_address <= v2_masterrd_address;
      masterrd2_read <= v2_masterrd_read;
      v2_enable_read <= '1' when state_read = st_extract_data else '0';
      v2_packets_to_read <= std_logic_vector(words2read);
      v2_address_init <= std_logic_vector(unsigned(ADDR_BASE_READ)+1+words2read);

  
  --STATE MACHINE TO GET HEADER
  
count_gen: process (clk, rst_n) is
begin  -- process count_gen
  if rst_n = '0' then                   -- asynchronous reset (active low)
    rdcount <= (others => '0');
    state_read <= st_idle;
  elsif clk'event and clk = '1' then    -- rising clock edge
    start_op_f <= start_op;
    case state_read is
      when st_idle =>
        rdcount <= (others => '0');
        words2read <= (others => '0');
        if start_op_f = '0' and start_op = '1' then
          state_read <= st_extract_header;
        else
          state_read <= st_idle;
        end if;

      when st_extract_header =>
        if masterrd1_waitrequest = '0' and masterrd1_readdatavalid = '1' then
          words2read <= unsigned(masterrd1_readdata);
          state_read <= st_extract_data;
        else
          state_read <= st_extract_header;
        end if;

      when st_extract_data =>
        if masterrd1_waitrequest = '0' and masterrd1_readdatavalid = '1' then
          if rdcount = words2read-1 then
            state_read <= st_finish;
            rdcount <= (others => '0');
          else
            rdcount <= rdcount + 1;
            state_read <= st_extract_data;
          end if;
        else
          rdcount <= rdcount;
          state_read <= state_read;
        end if;
        
      when st_finish =>
        state_read <= st_idle;

    end case;
    
  end if;
end process count_gen;

  


------ RESULT WRITE PROCESS  
  s_masterwrite <= '1' when state_write = st_write  else '0';--not fifoEmpty;
  masterwr_write <= s_masterwrite;
  masterwr_address <= s_address;
  masterwr_writedata <= std_logic_vector(unsigned(v1_data_out) + unsigned(v2_data_out));
  rdreq <= (not masterwr_waitrequest) and s_masterwrite;
  v1_get_read_data <= rdreq;
  v2_get_read_data <= rdreq;
  masterwr_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));


  stwrite_proc: process (clk, rst_n) is
  begin  -- process write_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      state_write <= st_idle;
    elsif clk'event and clk = '1' then  -- rising clock edge
      case state_write is
        when st_idle =>
          if (v1_burst_en = '1' and v2_burst_en = '1') then
            state_write <= st_write;
          else
            state_write <= st_idle;
          end if;

        when st_write =>
          if words_written_during_burst = BURST-1 then
            state_write <= st_idle;
          else
            state_write <= st_write;
          end if;
      end case;
      
    end if;
  end process stwrite_proc;
  
  waitreq_proc: process (clk, rst_n) is
  begin  -- process waitreq_proc
    if rst_n = '0' then           -- asynchronous reset (active low)
      s_address <= ADDR_BASE_WRITE;
      words_written_during_burst <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- ADDR UPDATE
      if rdreq = '1' then
        if rdcount = words2read-1 then --endofpacket received
          s_address <= ADDR_BASE_WRITE;
          words_written_during_burst <= (others => '0');
          rdcount <= (others => '0');
        else
          if words_written_during_burst = BURST-1 then
            words_written_during_burst <= (others => '0');
            s_address <= std_logic_vector(unsigned(s_address) + BURST);
          else
            words_written_during_burst <= words_written_during_burst + 1;
          end if;
          rdcount <= rdcount + 1;          
        end if;
      else
        rdcount <= rdcount;
        s_address <= s_address;
      end if; 
      
    end if;
  end process waitreq_proc;

  
end architecture bhv;
