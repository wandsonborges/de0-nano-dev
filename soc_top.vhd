library IEEE;
use IEEE.std_logic_1164.all;


entity soc_top is
  
  port (
    -- FPGA CONNECTIONS ---
    CLOCK_50 : in std_logic;
    SW       : in std_logic_vector(3 downto 0);
    LED      : out std_logic_vector(7 downto 0);

    --sensor pico384
    pico640_PICO_RST_N		: out   std_logic;
    pico640_PSYNC			: in    std_logic                     := '0';
    pico640_HSYNC			: in    std_logic                     := '0';
    pico640_VSYNC			: in    std_logic                     := '0';
    pico640_MC				: out   std_logic;
    pico640_SHUTTER         : out   std_logic;

    ADC_DATA				: in    std_logic_vector(13 downto 2) := (others => '0');
    ADC_CLOCK               : out   std_logic;

    --	I²C
    i2c_SCL					: inout std_logic;
    i2c_SDA					: inout std_logic;

    --GPIO
    MUX_I2C_ADC             : out std_logic;
    
    

    -- HPS CONNECTIONS ---HPS_CONV_USB_N:INOUT STD_LOGIC;
    HPS_DDR3_ADDR:OUT STD_LOGIC_VECTOR(14 downto 0);
    HPS_DDR3_BA: OUT STD_LOGIC_VECTOR(2 downto 0);
    HPS_DDR3_CAS_N: OUT STD_LOGIC;
    HPS_DDR3_CKE:OUT STD_LOGIC;
    HPS_DDR3_CK_N: OUT STD_LOGIC;
    HPS_DDR3_CK_P: OUT STD_LOGIC;
    HPS_DDR3_CS_N: OUT STD_LOGIC;
    HPS_DDR3_DM: OUT STD_LOGIC_VECTOR(3 downto 0);
    HPS_DDR3_DQ: INOUT STD_LOGIC_VECTOR(31 downto 0);
    HPS_DDR3_DQS_N: INOUT STD_LOGIC_VECTOR(3 downto 0);
    HPS_DDR3_DQS_P: INOUT STD_LOGIC_VECTOR(3 downto 0);
    HPS_DDR3_ODT: OUT STD_LOGIC;
    HPS_DDR3_RAS_N: OUT STD_LOGIC;
    HPS_DDR3_RESET_N: OUT  STD_LOGIC;
    HPS_DDR3_RZQ: IN  STD_LOGIC;
    HPS_DDR3_WE_N: OUT STD_LOGIC;
    HPS_ENET_GTX_CLK: OUT STD_LOGIC;
    HPS_ENET_INT_N:INOUT STD_LOGIC;
    HPS_ENET_MDC:OUT STD_LOGIC;
    HPS_ENET_MDIO:INOUT STD_LOGIC;
    HPS_ENET_RX_CLK: IN STD_LOGIC;
    HPS_ENET_RX_DATA: IN STD_LOGIC_VECTOR(3 downto 0);
    HPS_ENET_RX_DV: IN STD_LOGIC;
    HPS_ENET_TX_DATA: OUT STD_LOGIC_VECTOR(3 downto 0);
    HPS_ENET_TX_EN: OUT STD_LOGIC;
    HPS_KEY: INOUT STD_LOGIC;
    HPS_SD_CLK: OUT STD_LOGIC;
    HPS_SD_CMD: INOUT STD_LOGIC;
    HPS_SD_DATA: INOUT STD_LOGIC_VECTOR(3 downto 0);
    HPS_UART_RX: IN   STD_LOGIC;
    HPS_UART_TX: OUT STD_LOGIC;
    HPS_USB_CLKOUT: IN STD_LOGIC;
    HPS_USB_DATA:INOUT STD_LOGIC_VECTOR(7 downto 0);
    HPS_USB_DIR: IN STD_LOGIC;
    HPS_USB_NXT: IN STD_LOGIC;
    HPS_USB_STP: OUT STD_LOGIC
    
    );

end entity soc_top;


architecture bhv of soc_top is

  SIGNAL HPS_H2F_RST:STD_LOGIC;

  signal mm_fifo_full : STD_LOGIC := '0';
  signal mm_done : STD_LOGIC := '0';

  signal local_burst_transfer_wf_0_ctrl_busy: STD_LOGIC;
  signal ctrl_busy : STD_LOGIC := '0';
  signal read_valid2ctrl_write : STD_LOGIC := '0';
  signal read_data2ctrl_data : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal ctrl_address: STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

  
  signal ctrl_read: STD_LOGIC;

  component cycloneV_soc is
    port (
      mc_clk                         : out   std_logic;                                        --                     adc.clk      
      
      adc_clk                         : out   std_logic;                                        --                     adc.clk      
      clk_clk                         : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_TX_CLK : out   std_logic;
      hps_io_hps_io_emac1_inst_TXD0   : out   std_logic;
      hps_io_hps_io_emac1_inst_TXD1   : out   std_logic;
      hps_io_hps_io_emac1_inst_TXD2   : out   std_logic;
      hps_io_hps_io_emac1_inst_TXD3   : out   std_logic;
      hps_io_hps_io_emac1_inst_RXD0   : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_MDIO   : inout std_logic                     := '0';
      hps_io_hps_io_emac1_inst_MDC    : out   std_logic;
      hps_io_hps_io_emac1_inst_RX_CTL : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_TX_CTL : out   std_logic;
      hps_io_hps_io_emac1_inst_RX_CLK : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_RXD1   : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_RXD2   : in    std_logic                     := '0';
      hps_io_hps_io_emac1_inst_RXD3   : in    std_logic                     := '0';
      hps_io_hps_io_sdio_inst_CMD     : inout std_logic                     := '0';
      hps_io_hps_io_sdio_inst_D0      : inout std_logic                     := '0';
      hps_io_hps_io_sdio_inst_D1      : inout std_logic                     := '0';
      hps_io_hps_io_sdio_inst_CLK     : out   std_logic;
      hps_io_hps_io_sdio_inst_D2      : inout std_logic                     := '0';
      hps_io_hps_io_sdio_inst_D3      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D0      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D1      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D2      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D3      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D4      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D5      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D6      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_D7      : inout std_logic                     := '0';
      hps_io_hps_io_usb1_inst_CLK     : in    std_logic                     := '0';
      hps_io_hps_io_usb1_inst_STP     : out   std_logic;
      hps_io_hps_io_usb1_inst_DIR     : in    std_logic                     := '0';
      hps_io_hps_io_usb1_inst_NXT     : in    std_logic                     := '0';
      hps_io_hps_io_uart0_inst_RX     : in    std_logic                     := '0';
      hps_io_hps_io_uart0_inst_TX     : out   std_logic;
      i2c_SCL                         : out   std_logic;
      i2c_SDA                         : inout std_logic                     := '0';
      led_external_connection_export  : out   std_logic_vector(7 downto 0);
      memory_mem_a                    : out   std_logic_vector(14 downto 0);
      memory_mem_ba                   : out   std_logic_vector(2 downto 0);
      memory_mem_ck                   : out   std_logic;
      memory_mem_ck_n                 : out   std_logic;
      memory_mem_cke                  : out   std_logic;
      memory_mem_cs_n                 : out   std_logic;
      memory_mem_ras_n                : out   std_logic;
      memory_mem_cas_n                : out   std_logic;
      memory_mem_we_n                 : out   std_logic;
      memory_mem_reset_n              : out   std_logic;
      memory_mem_dq                   : inout std_logic_vector(31 downto 0) := (others => '0');
      memory_mem_dqs                  : inout std_logic_vector(3 downto 0)  := (others => '0');
      memory_mem_dqs_n                : inout std_logic_vector(3 downto 0)  := (others => '0');
      memory_mem_odt                  : out   std_logic;
      memory_mem_dm                   : out   std_logic_vector(3 downto 0);
      memory_oct_rzqin                : in    std_logic                     := '0';
      pico640_PSYNC                   : in    std_logic                     := '0';
      pico640_VSYNC                   : in    std_logic                     := '0';
      pico640_HSYNC                   : in    std_logic                     := '0';
      pico640_ADC_DATA                : in    std_logic_vector(13 downto 0) := (others => '0');
      pico640_SHUTTER                 : out   std_logic;
      pico640_SENSOR_RST_N            : out   std_logic;
      pico640_CLOCK_EN                : out   std_logic;
      pio_export                      : out   std_logic_vector(7 downto 0);
      reset_reset_n                   : in    std_logic                     := '0';
      sw_external_connection_export   : in    std_logic_vector(3 downto 0)  := (others => '0'));
  end component cycloneV_soc;

  signal lwir_syp, lwir_syt, lwir_syl, lwir_emu_clk : std_logic := '0';
  signal swir_fsync, swir_lsync, swir_pxl_clk, swir_sensor_clk : std_logic := '0';
  signal swir_1_fsync, swir_1_lsync, swir_1_pxl_clk, swir_1_sensor_clk : std_logic := '0';
  signal s_LED, lwir_data, swir_dataIn, swir_1_dataIn : std_logic_vector(7 downto 0) := (others => '0');
  
  signal mc_clk : std_logic;
  signal ADC_DATA_IN : std_logic_vector(13 downto 0);
  signal s_MUX : std_logic;
  signal s_i2c_scl : std_logic;
  signal gpio_export : std_logic_vector(7 downto 0);
  signal pico640_CLOCK_EN : std_logic;
  
begin  -- architecture bhv

  --D5M_XCLKIN <= CLOCK_50;

  cycloneV_soc_2: component cycloneV_soc
    port map (
      mc_clk                          => mc_clk,
      adc_clk                         => ADC_CLOCK,
      clk_clk                         => CLOCK_50,
      --hps_0_h2f_reset_reset_n         => HPS_H2F_RST,
      
      -- pxl_clk_clk                     => D5M_PIXCLK,
      -- d5m_camera_0_conduit_end_datain => D5M_D(11 downto 4),
      -- d5m_camera_0_conduit_end_fvalid => D5M_FVAL,
      -- d5m_camera_0_conduit_end_lvalid => D5M_LVAL,
      -- d5m_camera_0_conduit_end_start  => '1',
      -- d5m_camera_0_conduit_end_rst_sensor => D5M_RESET_N,
      -- d5m_camera_0_conduit_end_sclk   => D5M_SCLK,
      -- d5m_camera_0_conduit_end_sdata  => D5M_SDATA,
      -- d5m_camera_0_conduit_end_trigger => D5M_TRIGGER,
      -- pll_0_outclk0_clk => D5M_XCLKIN,
      --
      --

      
      led_external_connection_export =>  s_LED,
      memory_mem_a                    => HPS_DDR3_ADDR,
      memory_mem_ba                   => HPS_DDR3_BA,
      memory_mem_ck                   => HPS_DDR3_CK_P,
      memory_mem_ck_n                 => HPS_DDR3_CK_N,
      memory_mem_cke                  => HPS_DDR3_CKE,
      memory_mem_cs_n                 => HPS_DDR3_CS_N,
      memory_mem_ras_n                => HPS_DDR3_RAS_N,
      memory_mem_cas_n                => HPS_DDR3_CAS_N,
      memory_mem_we_n                 => HPS_DDR3_WE_N,
      memory_mem_reset_n              => HPS_DDR3_RESET_N,
      memory_mem_dq                   => HPS_DDR3_DQ,
      memory_mem_dqs                  => HPS_DDR3_DQS_P,
      memory_mem_dqs_n                => HPS_DDR3_DQS_N,
      memory_mem_odt                  => HPS_DDR3_ODT,
      memory_mem_dm                   => HPS_DDR3_DM,
      memory_oct_rzqin                => HPS_DDR3_RZQ,
      reset_reset_n                   => '1',
      sw_external_connection_export   => SW,

      pico640_PSYNC				=> pico640_PSYNC,
      pico640_VSYNC				=> pico640_VSYNC,
      pico640_HSYNC				=> pico640_HSYNC,
      pico640_SENSOR_RST_N        => pico640_PICO_RST_N,
      pico640_SHUTTER             => pico640_SHUTTER,
      pico640_ADC_DATA			=> ADC_DATA_IN,
      pico640_CLOCK_EN            => pico640_CLOCK_EN,
      
      
      pio_export                      => gpio_export,

      i2c_SCL						=> s_i2c_SCL,
      i2c_SDA                     => i2c_SDA,
      
      
      hps_io_hps_io_emac1_inst_TX_CLK => HPS_ENET_GTX_CLK,
      hps_io_hps_io_emac1_inst_TXD0   => HPS_ENET_TX_DATA(0),
      hps_io_hps_io_emac1_inst_TXD1   => HPS_ENET_TX_DATA(1),
      hps_io_hps_io_emac1_inst_TXD2   => HPS_ENET_TX_DATA(2),
      hps_io_hps_io_emac1_inst_TXD3   => HPS_ENET_TX_DATA(3),
      hps_io_hps_io_emac1_inst_RXD0   => HPS_ENET_RX_DATA(0),
      hps_io_hps_io_emac1_inst_MDIO   => HPS_ENET_MDIO,
      hps_io_hps_io_emac1_inst_MDC    => HPS_ENET_MDC,
      hps_io_hps_io_emac1_inst_RX_CTL => HPS_ENET_RX_DV,
      hps_io_hps_io_emac1_inst_TX_CTL => HPS_ENET_TX_EN,
      hps_io_hps_io_emac1_inst_RX_CLK => HPS_ENET_RX_CLK,
      hps_io_hps_io_emac1_inst_RXD1   => HPS_ENET_RX_DATA(1),
      hps_io_hps_io_emac1_inst_RXD2   => HPS_ENET_RX_DATA(2),
      hps_io_hps_io_emac1_inst_RXD3   => HPS_ENET_RX_DATA(3),
      hps_io_hps_io_sdio_inst_CMD     => HPS_SD_CMD,
      hps_io_hps_io_sdio_inst_D0      => HPS_SD_DATA(0),
      hps_io_hps_io_sdio_inst_D1      => HPS_SD_DATA(1),
      hps_io_hps_io_sdio_inst_CLK     => HPS_SD_CLK,
      hps_io_hps_io_sdio_inst_D2      => HPS_SD_DATA(2),
      hps_io_hps_io_sdio_inst_D3      => HPS_SD_DATA(3),
      hps_io_hps_io_usb1_inst_D0      => HPS_USB_DATA(0),
      hps_io_hps_io_usb1_inst_D1      => HPS_USB_DATA(1),
      hps_io_hps_io_usb1_inst_D2      => HPS_USB_DATA(2),
      hps_io_hps_io_usb1_inst_D3      => HPS_USB_DATA(3),
      hps_io_hps_io_usb1_inst_D4      => HPS_USB_DATA(4),
      hps_io_hps_io_usb1_inst_D5      => HPS_USB_DATA(5),
      hps_io_hps_io_usb1_inst_D6      => HPS_USB_DATA(6),
      hps_io_hps_io_usb1_inst_D7      => HPS_USB_DATA(7),
      hps_io_hps_io_usb1_inst_CLK     => HPS_USB_CLKOUT,
      hps_io_hps_io_usb1_inst_STP     => HPS_USB_STP,
      hps_io_hps_io_usb1_inst_DIR     => HPS_USB_DIR,
      hps_io_hps_io_usb1_inst_NXT     => HPS_USB_NXT,
      hps_io_hps_io_uart0_inst_RX     => HPS_UART_RX,
      hps_io_hps_io_uart0_inst_TX     => HPS_UART_TX
      );
		
      LED(6 downto 0) <= s_LED(6 downto 0);
  LED(7) <= SW(0);

  i2c_SCL <= s_i2c_scl when s_MUX = '1' else 'Z';
  MUX_I2C_ADC <= s_MUX;  
  ADC_DATA_IN <= ADC_DATA & i2c_SDA & i2c_SCL;
  pico640_MC <= mc_clk and pico640_CLOCK_EN;
  s_MUX 		<= gpio_export(0);
  
end architecture bhv;
