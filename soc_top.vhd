library IEEE;
use IEEE.std_logic_1164.all;


entity soc_top is
  
  port (
    -- FPGA CONNECTIONS ---
    CLOCK_50 : in std_logic;
    SW       : in std_logic_vector(3 downto 0);
    LED      : out std_logic_vector(7 downto 0);

    --D5M SIGNALS
    D5M_D : in std_logic_vector(11 downto 0);
    D5M_FVAL : in std_logic;
    D5M_LVAL : in std_logic;
    D5M_PIXCLK : in std_logic;
    D5M_RESET_N : out std_logic;
    D5M_SCLK : out std_logic;
    D5M_SDATA : inout std_logic;	
    D5M_STROBE : in std_logic;
    D5M_TRIGGER : out std_logic;
    D5M_XCLKIN : out std_logic;
        

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
            -- pxl_clk_clk                                                    : in    std_logic                     := 'X';             -- clk
	    --     	d5m_camera_0_conduit_end_datain                                : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- datain
	    --     	d5m_camera_0_conduit_end_fvalid                                : in    std_logic                     := 'X';             -- fvalid
	    --     	d5m_camera_0_conduit_end_lvalid                                : in    std_logic                     := 'X';             -- lvalid
	    --     	d5m_camera_0_conduit_end_start                                 : in    std_logic                     := 'X';             -- start
	    --     	d5m_camera_0_conduit_end_rst_sensor                            : out   std_logic;                                        -- rst_sensor
	    --     	d5m_camera_0_conduit_end_sclk                                  : out   std_logic;                                        -- sclk
	    --     	d5m_camera_0_conduit_end_sdata                                 : out   std_logic;                                        -- sdata
	    --     	d5m_camera_0_conduit_end_trigger                               : out   std_logic;                                        -- trigger
            --             pll_0_outclk0_clk : out std_logic;
		--burst_read_wf_0_ctrl_baseaddress   : in    std_logic_vector(31 downto 0) := (others => '0'); --    burst_read_wf_0_ctrl.baseaddress
		--burst_read_wf_0_ctrl_burstcount    : in    std_logi
		--c_vector(3 downto 0)  := (others => '0'); --                        .burstcount
		--burst_read_wf_0_ctrl_readdatavalid : out   std_logic;                                        --                        .readdatavalid
		--burst_read_wf_0_ctrl_readdata      : out   std_logic_vector(31 downto 0);                    --                        .readdata
		--burst_read_wf_0_ctrl_busy          : out   std_logic;                                        --                        .busy
		--burst_read_wf_0_ctrl_start         : in    std_logic                     := '0';             --                        .start
		--burst_read_wf_0_ctrl_address       : in    std_logic_vector(3 downto 0)  := (others => '0'); --                        .address
		--burst_read_wf_0_ctrl_read          : in    std_logic                     := '0';             --                        .read
		--burst_write_wf_0_ctrl_baseaddress  : in    std_logic_vector(31 downto 0) := (others => '0'); --   burst_write_wf_0_ctrl.baseaddress
		--burst_write_wf_0_ctrl_burstcount   : in    std_logic_vector(3 downto 0)  := (others => '0'); --                        .burstcount
		--burst_write_wf_0_ctrl_busy         : out   std_logic;                                        --                        .busy
		--burst_write_wf_0_ctrl_start        : in    std_logic                     := '0';             --                        .start
		--burst_write_wf_0_ctrl_write        : in    std_logic                     := '0';             --                        .write
		--burst_write_wf_0_ctrl_writedata    : in    std_logic_vector(31 downto 0) := (others => '0'); --                        .writedata
		--burst_write_wf_0_ctrl_address      : out   std_logic_vector(3 downto 0);                     --                        .address
		--burst_write_wf_0_ctrl_read         : out   std_logic;                                        --                        .read

			-- autocorrelation_0_conduit_end_databeingwrittentoexternalmemory : in    std_logic                     := 'X';             -- databeingwrittentoexternalmemory
			-- autocorrelation_0_conduit_end_enablesensordatatoexternalmemory : out   std_logic;                                        -- enablesensordatatoexternalmemory
			-- autocorrelation_0_conduit_end_memorycontrollerbusy             : in    std_logic                     := 'X';              -- memorycontrollerbusy

            
            lwir_ul0304_datain              : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- datain
            lwir_ul0304_syt                 : out   std_logic;                                        -- syt
            lwir_ul0304_syl                 : out   std_logic;                                        -- syl
            lwir_ul0304_syp                 : out   std_logic;
            --lwir_emu_clk_clk                : out   std_logic;


            swir_v400_sensor_clk            : out   std_logic;                                        -- sensor_clk
            swir_v400_datain                : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- datain
            swir_v400_fsync                 : out   std_logic;                                        -- fsync
            swir_v400_lsync                 : out   std_logic;                                        -- lsync
            swir_v400_swir_pxl_clk_out      : out   std_logic;

            swir_v400_1_sensor_clk            : out   std_logic;                                        -- sensor_clk
            swir_v400_1_datain                : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- datain
            swir_v400_1_fsync                 : out   std_logic;                                        -- fsync
            swir_v400_1_lsync                 : out   std_logic;                                        -- lsync
            swir_v400_1_swir_pxl_clk_out      : out   std_logic;
            
			clk_clk                                  : in    std_logic                     := 'X';             -- clk
			--hps_0_h2f_reset_reset_n                  : out   std_logic;                                        -- reset_n
			hps_io_hps_io_emac1_inst_TX_CLK          : out   std_logic;                                        -- hps_io_emac1_inst_TX_CLK
			hps_io_hps_io_emac1_inst_TXD0            : out   std_logic;                                        -- hps_io_emac1_inst_TXD0
			hps_io_hps_io_emac1_inst_TXD1            : out   std_logic;                                        -- hps_io_emac1_inst_TXD1
			hps_io_hps_io_emac1_inst_TXD2            : out   std_logic;                                        -- hps_io_emac1_inst_TXD2
			hps_io_hps_io_emac1_inst_TXD3            : out   std_logic;                                        -- hps_io_emac1_inst_TXD3
			hps_io_hps_io_emac1_inst_RXD0            : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RXD0
			hps_io_hps_io_emac1_inst_MDIO            : inout std_logic                     := 'X';             -- hps_io_emac1_inst_MDIO
			hps_io_hps_io_emac1_inst_MDC             : out   std_logic;                                        -- hps_io_emac1_inst_MDC
			hps_io_hps_io_emac1_inst_RX_CTL          : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RX_CTL
			hps_io_hps_io_emac1_inst_TX_CTL          : out   std_logic;                                        -- hps_io_emac1_inst_TX_CTL
			hps_io_hps_io_emac1_inst_RX_CLK          : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RX_CLK
			hps_io_hps_io_emac1_inst_RXD1            : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RXD1
			hps_io_hps_io_emac1_inst_RXD2            : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RXD2
			hps_io_hps_io_emac1_inst_RXD3            : in    std_logic                     := 'X';             -- hps_io_emac1_inst_RXD3
			hps_io_hps_io_sdio_inst_CMD              : inout std_logic                     := 'X';             -- hps_io_sdio_inst_CMD
			hps_io_hps_io_sdio_inst_D0               : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D0
			hps_io_hps_io_sdio_inst_D1               : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D1
			hps_io_hps_io_sdio_inst_CLK              : out   std_logic;                                        -- hps_io_sdio_inst_CLK
			hps_io_hps_io_sdio_inst_D2               : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D2
			hps_io_hps_io_sdio_inst_D3               : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D3
			hps_io_hps_io_usb1_inst_D0               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D0
			hps_io_hps_io_usb1_inst_D1               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D1
			hps_io_hps_io_usb1_inst_D2               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D2
			hps_io_hps_io_usb1_inst_D3               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D3
			hps_io_hps_io_usb1_inst_D4               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D4
			hps_io_hps_io_usb1_inst_D5               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D5
			hps_io_hps_io_usb1_inst_D6               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D6
			hps_io_hps_io_usb1_inst_D7               : inout std_logic                     := 'X';             -- hps_io_usb1_inst_D7
			hps_io_hps_io_usb1_inst_CLK              : in    std_logic                     := 'X';             -- hps_io_usb1_inst_CLK
			hps_io_hps_io_usb1_inst_STP              : out   std_logic;                                        -- hps_io_usb1_inst_STP
			hps_io_hps_io_usb1_inst_DIR              : in    std_logic                     := 'X';             -- hps_io_usb1_inst_DIR
			hps_io_hps_io_usb1_inst_NXT              : in    std_logic                     := 'X';             -- hps_io_usb1_inst_NXT
			hps_io_hps_io_uart0_inst_RX              : in    std_logic                     := 'X';             -- hps_io_uart0_inst_RX
			hps_io_hps_io_uart0_inst_TX              : out   std_logic;                                        -- hps_io_uart0_inst_TX
			led_external_connection_export           : out   std_logic_vector(7 downto 0);                     -- export
			memory_mem_a                             : out   std_logic_vector(14 downto 0);                    -- mem_a
			memory_mem_ba                            : out   std_logic_vector(2 downto 0);                     -- mem_ba
			memory_mem_ck                            : out   std_logic;                                        -- mem_ck
			memory_mem_ck_n                          : out   std_logic;                                        -- mem_ck_n
			memory_mem_cke                           : out   std_logic;                                        -- mem_cke
			memory_mem_cs_n                          : out   std_logic;                                        -- mem_cs_n
			memory_mem_ras_n                         : out   std_logic;                                        -- mem_ras_n
			memory_mem_cas_n                         : out   std_logic;                                        -- mem_cas_n
			memory_mem_we_n                          : out   std_logic;                                        -- mem_we_n
			memory_mem_reset_n                       : out   std_logic;                                        -- mem_reset_n
			memory_mem_dq                            : inout std_logic_vector(31 downto 0) := (others => 'X'); -- mem_dq
			memory_mem_dqs                           : inout std_logic_vector(3 downto 0)  := (others => 'X'); -- mem_dqs
			memory_mem_dqs_n                         : inout std_logic_vector(3 downto 0)  := (others => 'X'); -- mem_dqs_n
			memory_mem_odt                           : out   std_logic;                                        -- mem_odt
			memory_mem_dm                            : out   std_logic_vector(3 downto 0);                     -- mem_dm
			memory_oct_rzqin                         : in    std_logic                     := 'X';             -- oct_rzqin
			reset_reset_n                            : in    std_logic                     := 'X';             -- reset_n
			sw_external_connection_export            : in    std_logic_vector(3 downto 0)  := (others => 'X') -- export
----			avalon_mm_temp_1_conduit_end_usrwritebuf   :in    std_logic                     := 'X';             -- usrwritebuf
----			avalon_mm_temp_1_conduit_end_ctrldone    : out   std_logic;                                        -- ctrldone
----			avalon_mm_temp_1_conduit_end_ctrlfxdloc  : in    std_logic                     := 'X';             -- ctrlfxdloc
----			avalon_mm_temp_1_conduit_end_ctrlgo      : in    std_logic                     := 'X';             -- ctrlgo
----			avalon_mm_temp_1_conduit_end_usrdata     : in    std_logic_vector(31 downto 0) := (others => 'X'); -- usrdata
----			avalon_mm_temp_1_conduit_end_usrbuffull  : out   std_logic;                                        -- usrbuffull
----			avalon_mm_temp_1_conduit_end_ctrlbase    : in    std_logic_vector(31 downto 0) := (others => 'X'); -- ctrlbase
----			avalon_mm_temp_1_conduit_end_ctrllength  : in    std_logic_vector(31 downto 0) := (others => 'X')  -- ctrllength
		);
	end component cycloneV_soc;
  signal lwir_syp, lwir_syt, lwir_syl, lwir_emu_clk : std_logic := '0';
  signal swir_fsync, swir_lsync, swir_pxl_clk, swir_sensor_clk : std_logic := '0';
  signal swir_1_fsync, swir_1_lsync, swir_1_pxl_clk, swir_1_sensor_clk : std_logic := '0';
  signal s_LED, lwir_data, swir_dataIn, swir_1_dataIn : std_logic_vector(7 downto 0) := (others => '0');
begin  -- architecture bhv

  --D5M_XCLKIN <= CLOCK_50;

  swir_emulator_1: entity work.swir_emulator
    generic map (
      NUMERO_COLUNAS    => 640, --320,
      NUMERO_LINHAS     => 480, --256,
      SIMULATOR_PATTERN => false)
    port map (
      pxl_clock => swir_pxl_clk,
      s_clock   => swir_sensor_clk,
      rst_n     => SW(1),
      lsync     => swir_lsync,
      fsync     => swir_fsync,
      data_out  => swir_dataIn);

  swir_emulator_2: entity work.swir_emulator
    generic map (
      NUMERO_COLUNAS    => 640, --320,
      NUMERO_LINHAS     => 480, --256,
      SIMULATOR_PATTERN => false)
    port map (
      pxl_clock => swir_1_pxl_clk,
      s_clock   => swir_1_sensor_clk,
      rst_n     => SW(1),
      lsync     => swir_1_lsync,
      fsync     => swir_1_fsync,
      data_out  => swir_1_dataIn);
  
  lwir_UL_03_04_emulator_1: entity work.lwir_UL_03_04_emulator
    generic map (
      N_BITS_COL => 9,
      N_BITS_LIN => 9,
      NUM_COLS   => 384,
      NUM_LINES  => 288,
      N_BITS_PXL => 8)
    port map (
      clk      => swir_pxl_clk,
      rst_n    => SW(1),
      en       => '1',
      sens_syt => lwir_syt,
      sens_syl => lwir_syl,
      sens_syp => lwir_syp,
      pxl_out  => lwir_data
      );
  
  cycloneV_soc_2: component cycloneV_soc
    port map (
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

      swir_v400_sensor_clk            => swir_sensor_clk,
            swir_v400_datain                => swir_dataIn,                --                        .datain
            swir_v400_fsync                 => swir_fsync,                 --                        .fsync
            swir_v400_lsync                 => swir_lsync,                 --                        .lsync
      swir_v400_swir_pxl_clk_out      => swir_pxl_clk,

            swir_v400_1_sensor_clk            => swir_1_sensor_clk,
            swir_v400_1_datain                => swir_1_dataIn,                --                        .datain
            swir_v400_1_fsync                 => swir_1_fsync,                 --                        .fsync
            swir_v400_1_lsync                 => swir_1_lsync,                 --                        .lsync
            swir_v400_1_swir_pxl_clk_out      => swir_1_pxl_clk,

      lwir_ul0304_datain              => lwir_data,              --             lwir_ul0304.datain
      lwir_ul0304_syt                 => lwir_syt,
      lwir_ul0304_syl                 => lwir_syl, 
      lwir_ul0304_syp                 => lwir_syp,

      --lwir_emu_clk_clk                => lwir_emu_clk,

      
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
      -- autocorrelation_0_conduit_end_databeingwrittentoexternalmemory => '0',
      -- autocorrelation_0_conduit_end_enablesensordatatoexternalmemory  => open,
      -- autocorrelation_0_conduit_end_memorycontrollerbusy             => '0'
     --burst_read_wf_0_ctrl_baseaddress          => x"39000000",          --     burst_read_wf_0_ctrl.baseaddress
     --burst_read_wf_0_ctrl_burstcount           => "1000",           --                         .burstcount
     --burst_read_wf_0_ctrl_readdatavalid        => read_valid2ctrl_write,        --                         .readdatavalid
     --burst_read_wf_0_ctrl_readdata             => read_data2ctrl_data,             --                         .readdata
     --burst_read_wf_0_ctrl_busy => open, --                         .writeresponsevalid_n
     --burst_read_wf_0_ctrl_start   => not ctrl_busy,   --                         .beginbursttransfer
     --burst_read_wf_0_ctrl_address          => ctrl_address,          --     burst_read_wf_0_ctrl.baseaddress
     --   burst_read_wf_0_ctrl_read 	=> ctrl_read,
     --burst_write_wf_0_ctrl_baseaddress      => x"38000000",      -- burst_transfer_wf_0_ctrl.baseaddress
     --burst_write_wf_0_ctrl_burstcount       => "1000",       --                         .burstcount
     --burst_write_wf_0_ctrl_busy             => ctrl_busy,             --                         .busy
     --burst_write_wf_0_ctrl_start            => read_valid2ctrl_write, --not ctrl_busy,            --                         .start
     --burst_write_wf_0_ctrl_address      => ctrl_address,      -- burst_transfer_wf_0_ctrl.baseaddress
     --burst_write_wf_0_ctrl_write            => read_valid2ctrl_write,            --                         .write
     --   burst_write_wf_0_ctrl_read 	=> ctrl_read,
     --burst_write_wf_0_ctrl_writedata        => read_data2ctrl_data         --                         .writedata
      );
		
      LED(6 downto 0) <= s_LED(6 downto 0);
      LED(7) <= SW(0) or SW(3);
  
end architecture bhv;
