library IEEE;
use IEEE.std_logic_1164.all;


entity soc_top is
  
  port (
    -- FPGA CONNECTIONS ---
    CLOCK_50 : in std_logic;
    SW       : in std_logic_vector(3 downto 0);
    LED      : out std_logic_vector(7 downto 0);

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
  

	component cycloneV_soc is
          port (
		burst_read_wf_0_ctrl_baseaddress   : in    std_logic_vector(31 downto 0) := (others => '0'); --    burst_read_wf_0_ctrl.baseaddress
		burst_read_wf_0_ctrl_burstcount    : in    std_logic_vector(3 downto 0)  := (others => '0'); --                        .burstcount
		burst_read_wf_0_ctrl_readdatavalid : out   std_logic;                                        --                        .readdatavalid
		burst_read_wf_0_ctrl_readdata      : out   std_logic_vector(31 downto 0);                    --                        .readdata
		burst_read_wf_0_ctrl_busy          : out   std_logic;                                        --                        .busy
		burst_read_wf_0_ctrl_start         : in    std_logic                     := '0';             --                        .start
		burst_read_wf_0_ctrl_address       : in    std_logic_vector(3 downto 0)  := (others => '0'); --                        .address
		burst_write_wf_0_ctrl_baseaddress  : in    std_logic_vector(31 downto 0) := (others => '0'); --   burst_write_wf_0_ctrl.baseaddress
		burst_write_wf_0_ctrl_burstcount   : in    std_logic_vector(3 downto 0)  := (others => '0'); --                        .burstcount
		burst_write_wf_0_ctrl_busy         : out   std_logic;                                        --                        .busy
		burst_write_wf_0_ctrl_start        : in    std_logic                     := '0';             --                        .start
		burst_write_wf_0_ctrl_write        : in    std_logic                     := '0';             --                        .write
		burst_write_wf_0_ctrl_writedata    : in    std_logic_vector(31 downto 0) := (others => '0'); --                        .writedata
		burst_write_wf_0_ctrl_address      : out   std_logic_vector(3 downto 0);                     --                        .address
    
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
  
  signal s_LED : std_logic_vector(7 downto 0) := (others => '0');
begin  -- architecture bhv

  cycloneV_soc_2: component cycloneV_soc
    port map (
      clk_clk                         => CLOCK_50,
      --hps_0_h2f_reset_reset_n         => HPS_H2F_RST,
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
      hps_io_hps_io_uart0_inst_TX     => HPS_UART_TX,
      burst_read_wf_0_ctrl_baseaddress          => x"39000000",          --     burst_read_wf_0_ctrl.baseaddress
      burst_read_wf_0_ctrl_burstcount           => "1000",           --                         .burstcount
      burst_read_wf_0_ctrl_readdatavalid        => read_valid2ctrl_write,        --                         .readdatavalid
      burst_read_wf_0_ctrl_readdata             => read_data2ctrl_data,             --                         .readdata
      burst_read_wf_0_ctrl_busy => open, --                         .writeresponsevalid_n
      burst_read_wf_0_ctrl_start   => not ctrl_busy,   --                         .beginbursttransfer
      burst_read_wf_0_ctrl_address          => ctrl_address,          --     burst_read_wf_0_ctrl.baseaddress
      burst_write_wf_0_ctrl_baseaddress      => x"38000000",      -- burst_transfer_wf_0_ctrl.baseaddress
      burst_write_wf_0_ctrl_burstcount       => "1000",       --                         .burstcount
      burst_write_wf_0_ctrl_busy             => ctrl_busy,             --                         .busy
      burst_write_wf_0_ctrl_start            => read_valid2ctrl_write, --not ctrl_busy,            --                         .start
      burst_write_wf_0_ctrl_address      => ctrl_address,      -- burst_transfer_wf_0_ctrl.baseaddress
      burst_write_wf_0_ctrl_write            => read_valid2ctrl_write,            --                         .write
      burst_write_wf_0_ctrl_writedata        => read_data2ctrl_data         --                         .writedata
      );
		
      LED(6 downto 0) <= s_LED(6 downto 0);
      LED(7) <= SW(0) or SW(3);
  
end architecture bhv;
