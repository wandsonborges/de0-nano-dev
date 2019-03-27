library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity nuc_avalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 1024;
    FIFO_SIZE_BITS : integer := 10;
    NBITS_DATA : integer := 8;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8;
    ADDR_BASE_READ : std_logic_vector(31 downto 0) := x"38100000"
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
    clk_mem    : in std_logic;

    -- avalon ST Sink - Get Raw Frame
    st_sink_startofpacket : in std_logic;
    st_sink_endofpacket   : in std_logic;
    st_sink_datain        : in std_logic_vector(NBITS_DATA-1 downto 0);
    st_sink_datavalid     : in std_logic;
    st_sink_ready         : out std_logic;
        
    -- avalon MM Master - Get Ref Frame
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_burstcount   : out std_logic_vector(3 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic;

    -- avalon ST Source - Generate Nuc Frame
    st_src_startofpacket : out std_logic;
    st_src_endofpacket   : out std_logic;
    st_src_ready         : in std_logic;
    st_src_data          : out std_logic_vector(NBITS_DATA-1 downto 0);
    st_src_datavalid     : out std_logic;
    
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

end entity nuc_avalon;

architecture bhv of nuc_avalon is

-- CONFIGURE ADD VECTOR HW SIGNALS
  type reg_type is array (0 to 4) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223377", --id
    x"00014000", --vectorSize
    x"00000001", --start
    ADDR_BASE_READ, --addr ref frame
    x"00000000" --busy
    );
  signal registers : reg_type := init_registers;
  constant FRAME_SIZE_REG_INDEX : integer := 1;

  -- Avalon mm Read signals
  signal mm_enable_read            : std_logic;
  signal mm_packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal mm_address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal mm_get_read_data          : std_logic;
  signal mm_data_ready             : std_logic;
  signal mm_data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal mm_burst_en               : std_logic;

  -- Avalon ST write signals
  signal st_fifo_data_in : std_logic_vector(NBITS_DATA+1 downto 0);
  signal st_fifo_data_out : std_logic_vector(NBITS_DATA+1 downto 0);
  signal st_fifo_wr_clk : std_logic;
  signal st_fifo_rd_clk : std_logic;
  signal st_fifo_write : std_logic;
  signal st_fifo_read : std_logic;
  signal st_fifo_full : std_logic;
  signal st_fifo_empty : std_logic;

  --mean frame calc signals
  signal ref_mean_value : std_logic_vector(NBITS_DATA-1 downto 0);

  --NUC signals
  signal nuc_pxl : std_logic_vector(NBITS_DATA-1 downto 0);

  signal sync_teste : std_logic := '0';
  signal pxl_line_count : std_logic_vector(NBITS_DATA-1 downto 0);


--general signal
  signal rdreq_sync, enable_fifo_write : std_logic := '0';


  --dcFifo

  	COMPONENT dcfifo
	GENERIC (
		intended_device_family		: STRING;
		lpm_numwords		: NATURAL;
		lpm_showahead		: STRING;
		lpm_type		: STRING;
		lpm_width		: NATURAL;
		lpm_widthu		: NATURAL;
		overflow_checking		: STRING;
		rdsync_delaypipe		: NATURAL;
		underflow_checking		: STRING;
		use_eab		: STRING;
		wrsync_delaypipe		: NATURAL
	);
	PORT (
			data	: IN STD_LOGIC_VECTOR (NBITS_DATA+1 DOWNTO 0);
			rdclk	: IN STD_LOGIC ;
			rdreq	: IN STD_LOGIC ;
			wrclk	: IN STD_LOGIC ;
			wrreq	: IN STD_LOGIC ;
			q	: OUT STD_LOGIC_VECTOR (NBITS_DATA+1 DOWNTO 0);
			rdempty	: OUT STD_LOGIC ;
			wrfull	: OUT STD_LOGIC 
	);
	END COMPONENT;

begin

  rdreq_sync <= st_src_ready and mm_data_ready and (not st_fifo_empty);
  --rdreq_sync <= (not st_fifo_empty) and st_src_ready; -- funcionou
  
  -- read packets
   readPacketsAvalon_1: entity work.readPacketsAvalon
    generic map (
      NBITS_ADDR    => NBITS_ADDR,
      NBITS_DATA    => NBITS_DATA,
      NBITS_PACKETS => NBITS_PACKETS,
      FIFO_SIZE     => FIFO_SIZE,
      FIFO_SIZE_BITS => FIFO_SIZE_BITS)
    port map (
      clk                    => clk_mem,
      rst_n                  => rst_n,
      masterrd_waitrequest   => masterrd_waitrequest,
      masterrd_readdatavalid => masterrd_readdatavalid,
      masterrd_readdata      => masterrd_readdata,
      masterrd_address       => masterrd_address,
      masterrd_read          => masterrd_read,
      masterrd_burstcount    => masterrd_burstcount,
      enable_read            => mm_enable_read,
      packets_to_read        => mm_packets_to_read,
      address_init           => mm_address_init,
      get_read_data          => mm_get_read_data,
      data_ready             => mm_data_ready,
      burst_en               => mm_burst_en,
      data_out               => mm_data_out);
   
   mm_packets_to_read <= registers(1);
   mm_enable_read <= registers(2)(0);
   mm_address_init <= registers(3);
   
   mm_get_read_data <= rdreq_sync;



   -- AVALON ST WRITING IN FIFO
   
   	dcfifo_component : dcfifo
	GENERIC MAP (
		intended_device_family => "Cyclone V",
		lpm_numwords => 4096,
		lpm_showahead => "ON",
		lpm_type => "dcfifo",
		lpm_width => NBITS_DATA+2,
		lpm_widthu => 12,
		overflow_checking => "ON",
		rdsync_delaypipe => 4,
		underflow_checking => "ON",
		use_eab => "ON",
		wrsync_delaypipe => 4
	)
	PORT MAP (
		data => st_fifo_data_in,
		rdclk => st_fifo_rd_clk,
		rdreq => st_fifo_read,
		wrclk => st_fifo_wr_clk,
		wrreq => st_fifo_write,
		q => st_fifo_data_out,
		rdempty => st_fifo_empty,
		wrfull => st_fifo_full
	);

   st_fifo_data_in <= st_sink_endofpacket & st_sink_startofpacket & st_sink_datain;
   st_fifo_write <= st_sink_datavalid and enable_fifo_write;
   st_fifo_wr_clk <= clk;

   st_fifo_read <= rdreq_sync; 
   st_fifo_rd_clk <= clk_mem;

   -- ST source
   st_src_datavalid <= st_fifo_read;
   st_src_endofpacket <= st_fifo_data_out(NBITS_DATA+1);
   st_src_startofpacket <= st_fifo_data_out(NBITS_DATA);
  --st_src_data <= std_logic_vector(unsigned(st_fifo_data_out(NBITS_DATA-1 downto 0)) - unsigned(mm_data_out)) ;
   st_src_data <= nuc_pxl;
   --st_src_data <= st_fifo_data_out(NBITS_DATA-1 downto 0); 
   

   enable_fifo_wr_sync_proc: process (clk, rst_n) is
   begin  -- process enable_fifo_wr_sync_proc
     if rst_n = '0' then                -- asynchronous reset (active low)
       enable_fifo_write <= '0';
     elsif clk'event and clk = '1' then  -- rising clock edge
       -- wait for first endofpacket to start write new packet from beginning       
       if st_sink_endofpacket = '1' and st_sink_datavalid = '1' then
         enable_fifo_write <= '1';
       else
         enable_fifo_write <= enable_fifo_write;
       end if;       
     end if;
   end process enable_fifo_wr_sync_proc;

  mean_frame_1: entity work.mean_frame
    generic map (
      NBITS_PXL => NBITS_DATA)
    port map (
      rst_n      => rst_n,
      clk        => clk_mem,
      pxl_valid  => mm_get_read_data,
      frame_size => registers(FRAME_SIZE_REG_INDEX),
      pxl_value  => mm_data_out,
      mean_value => ref_mean_value);

  nuc_core_1: entity work.nuc_core
    generic map (
      NBITS_DATA => NBITS_DATA)
    port map (
      enable   => '1',
      pxl_raw  => st_fifo_data_out(NBITS_DATA-1 downto 0),
      pxl_ref  => mm_data_out,
      mean_ref => ref_mean_value, --(others => '0'),
      pxl_out  => nuc_pxl);

  
end architecture bhv;
