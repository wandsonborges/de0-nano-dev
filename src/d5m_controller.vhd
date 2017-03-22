library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity d5m_controller is
  generic (
    LINES : integer := 480;
    COLS  : integer := 800
    );
  port (
    clk, rst_n  : in std_logic;
    
    start       : in std_logic;
    frame_valid : in std_logic;
    line_valid  : in std_logic;
    data_in     : in std_logic_vector(7 downto 0);

    sclk        : out std_logic;
    sdata       : inout std_logic;

    rst_sensor  : out std_logic;
    trigger     : out std_logic;

    --Avalon ST
    data_valid  : out std_logic;
    data_out    : out std_logic_vector(7 downto 0);
    startofpacket : out std_logic;
    endofpacket : out std_logic
    );
  
end entity d5m_controller;

architecture bhv of d5m_controller is
  signal line_valid_s : std_logic := '0';
  signal data_out_s : std_logic_vector(7 downto 0) := (others => '0');

  signal ff_frame_valid, ff_line_valid : std_logic := '0';

  signal pxl_counter : unsigned(31 downto 0) := (others => '0');

  signal rst_n2, mirror, exp_up, exp_down : std_logic := '0';
  
  type state_type is (st_idle, st_fot, st_valid_data);
  signal state : state_type := st_idle;

--   COMPONENT I2C_CCD_Config
-- 	GENERIC ( default_exposure : STD_LOGIC_VECTOR(15 DOWNTO 0) := b"0000010111100101"; exposure_change_value : STD_LOGIC_VECTOR(15 DOWNTO 0) := b"0000000000110010"; CLK_Freq : INTEGER := 50000000; I2C_Freq : INTEGER := 20000;
-- 		 LUT_SIZE : INTEGER := 25 );
-- 	PORT
-- 	(
-- 		iCLK		:	 IN STD_LOGIC;
-- 		iRST_N		:	 IN STD_LOGIC;
-- 		iMIRROR_SW		:	 IN STD_LOGIC;
-- 		iEXPOSURE_ADJ		:	 IN STD_LOGIC;
-- 		iEXPOSURE_DEC_p		:	 IN STD_LOGIC;
-- 		I2C_SCLK		:	 OUT STD_LOGIC;
-- 		I2C_SDAT		:	 INOUT STD_LOGIC
-- 	);
--   END COMPONENT;

--   COMPONENT Reset_Delay
-- 	PORT
-- 	(
-- 		iCLK		:	 IN STD_LOGIC;
-- 		iRST		:	 IN STD_LOGIC;
-- 		oRST_0		:	 OUT STD_LOGIC;
-- 		oRST_1		:	 OUT STD_LOGIC;
-- 		oRST_2		:	 OUT STD_LOGIC;
-- 		oRST_3		:	 OUT STD_LOGIC;
-- 		oRST_4		:	 OUT STD_LOGIC
-- 	);
-- END COMPONENT;
begin  -- architecture bhv

  -- I2C_CCD_Config_1: entity work.I2C_CCD_Config
  --   generic map (
  --     CLK_Freq              => 50000000,
  --     I2C_Freq              => 20000,
  --     LUT_SIZE              => 25)
  --   port map (
  --     iCLK            => clk,
  --     iRST_N          => rst_n2,
  --     iMIRROR_SW      => '0',
  --     iEXPOSURE_ADJ   => '0',
  --     iEXPOSURE_DEC_p => '0',
  --     I2C_SCLK        => sclk,
  --     I2C_SDAT        => sdata);

  Reset_Delay_1: entity work.Reset_Delay
    port map (
      iCLK   => clk,
      iRST   => rst_n,
      oRST_0 => open,
      oRST_1 => open,
      oRST_2 => rst_n2,
      oRST_3 => open,
      oRST_4 => open);

---------------------------------------------------
  -- AVALON ST SIGNALS GENERATE --------------------
  proc: process (clk, rst_n) is
  begin  -- process proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      state <= st_idle;
      startofpacket <= '0';
      endofpacket <= '0';
      ff_frame_valid <= '0';
      ff_line_valid <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      ff_frame_valid <= frame_valid;
      ff_line_valid <= line_valid;
      case state is
        when st_idle =>
          endofpacket <= '0';
          if frame_valid = '1' and ff_frame_valid = '0' then
            if line_valid = '1' and ff_line_valid = '0' then
              state <= st_valid_data;
              startofpacket <= '1';
            else
              state <= st_fot;
            end if;            
          else
            state <= st_idle;
          end if;

        when st_fot =>
          if ff_line_valid = '0' and line_valid = '1' then
            state <= st_valid_data;
            startofpacket <= '1';
          else
            state <= st_fot;
          end if;

        when st_valid_data =>
          startofpacket <= '0';
          if pxl_counter = (COLS*LINES)-1 then
            pxl_counter <= (others => '0');
            state <= st_idle;
            endofpacket <= '0';          
          elsif line_valid = '1' then
          if pxl_counter = (COLS*LINES)-2 then
            endofpacket <= '1';
            state <= st_valid_data;
            pxl_counter <= pxl_counter + 1;
          else
            pxl_counter <= pxl_counter + 1;
            state <= st_valid_data;
            endofpacket <= '0';
          end if;
      end if;
          
          
          --if ff_frame_valid <= '1' and frame_valid = '0' then
          --  endofpacket <= '1';
          --  state <= st_idle;
          --else
          --  state <= st_valid_data;
          --end if;
      end case;    
    end if;
  end process proc;

  fake_data_proc: process (clk, rst_n) is
  begin  -- process fake_data_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      data_out_s <= (others => '0');
      line_valid_s <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      data_out_s <= data_in;
      line_valid_s <= line_valid;
    end if;
    
  end process fake_data_proc;

  data_out <= std_logic_vector(data_out_s);
  data_valid <= '1' when (state = st_valid_data) and line_valid_s = '1'
                and frame_valid = '1'  else '0';

  trigger <= '1';
  
  

end architecture bhv;

