library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lwir_ul0304_avalon is
  generic (NUM_COLS : integer := 320;
           NUM_ROWS : integer := 256;           
           NBITS_PXL : integer := 8
           );
  port(
-- clocks and resets
    sensor_clk_in    : in std_logic; --7.5Mhz
    rst_n            : in std_logic;
    
-- avalon MM Slave - Configure addVector Hardware
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(0 downto 0);
    slave_byteenable    : in std_logic_vector(3 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0);

-- avalon ST interface    
    st_data_valid  : out std_logic;
    st_data_out    : out std_logic_vector(7 downto 0);
    st_startofpacket : out std_logic;
    st_endofpacket : out std_logic;
    
-- exclusive lwir signals
    lwir_dataIn     : in std_logic_vector(NBITS_PXL-1 downto 0);
    lwir_syt        : out std_logic;
    lwir_syl        : out std_logic;
    lwir_syp        : out std_logic
    
    );
end lwir_ul0304_avalon;

architecture bhv of lwir_ul0304_avalon is

    -- CONFIGURE ADD VECTOR HW SIGNALS
  type reg_type is array (0 to 1) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"10000001", --id
    x"00000000" --busy
    );
  signal registers : reg_type := init_registers;


  --LWIR_CONTROL SIGNALS
  constant FRAME_SIZE : integer := NUM_COLS*NUM_ROWS;
  signal pxl_count : unsigned(31 downto 0) := (others => '0');
  signal lwir_dataValid : std_logic := '0';
  signal lwir_dataOut : std_logic_vector(NBITS_PXL-1 downto 0) := (others => '0');
  
begin

  -- AVALON SLAVE: ADD VECTOR HW CONF
 rd_wr_slave_proc: process (sensor_clk_in, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      registers <= init_registers;
    elsif sensor_clk_in'event and sensor_clk_in = '1' then  -- rising clock edge     
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
      
    end if;
  end process rd_wr_slave_proc;

  st_startofpacket <= '1' when pxl_count = 0 and lwir_dataValid = '1'
                   else '0';
  st_endofpacket <= '1' when pxl_count = FRAME_SIZE-1 and lwir_dataValid = '1'
                 else '0';
  st_data_out <= lwir_dataOut;
  st_data_valid <= lwir_dataValid;
 
  lwir_UL_03_04_controller_1: entity work.lwir_UL_03_04_controller
    generic map (
      NUM_COLS   => 384,
      NUM_LINES  => 288,
      N_BITS_PXL => NBITS_PXL,
      ROI_EN     => true,
      ROI_COL    => NUM_COLS,
      ROI_LINE   => NUM_ROWS,
      CLOCK_FREQ => 7500000,
      FRAME_RATE => 20)
    port map (
      clk         => sensor_clk_in,
      rst_n       => rst_n,
      en          => '1',
      invert_data => '1',
      pxl_in      => lwir_dataIn,
      pxl_out     => lwir_dataOut,
      sens_syt    => lwir_syt,
      sens_syl    => lwir_syl,
      sens_syp    => lwir_syp,
      pxl_valid   => lwir_dataValid);
  
pxl_count_proc: process (sensor_clk_in, rst_n) is
begin  -- process pxl_count_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    pxl_count <= (others => '0');
  elsif sensor_clk_in'event and sensor_clk_in = '1' then  -- rising clock edge
    if (pxl_count = FRAME_SIZE-1 and lwir_dataValid = '1') then
      pxl_count <= (others => '0');
    elsif (lwir_dataValid = '1') then
      pxl_count <= pxl_count + 1;
    else
      pxl_count <= pxl_count;
    end if;
  end if;  
end process pxl_count_proc;
end bhv;
