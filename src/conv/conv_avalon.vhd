library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

LIBRARY lpm;
USE lpm.lpm_components.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity conv_avalon is
  
  generic (
    MAX_COLS : integer := 2592;
    NBITS_ADDR : integer := 32;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Conv Image
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    

    -- avalon MM Master 2 - Get Raw Image
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic;
    
    -- avalon MM Slave - Configure Convolution
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(4 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0)   
    );               

end entity conv_avalon;

architecture bhv of conv_avalon is
  
  signal col_counter : unsigned(NBITS_COLS-1 downto 0) := (others => '0');
  signal line_counter : unsigned(NBITS_LINES-1 downto 0) := (others => '0');

  signal start_conv, start_conv_f : std_logic := '0';
  
-- BUFFER ADDR:
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38C00000";

  signal addr_init_rd  : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_READ;
  signal addr_init_wr  : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_WRITE;
  

       -- AVALON SIGNALS
  signal s_masterwrite, s_masterread : std_logic := '0';
  constant AVALON_MAXIMUM_PENDING_READS : integer := 64;
  
  --READ PARAMETER STATE MACHINE
  -- window Gen signals
  signal window_valid, pxl_valid : std_logic;
  signal window_data  : window_type;

  --conv_core signals
  signal pxl_result       : std_logic_vector(NBITS_DATA-1 downto 0);
  signal pxl_result_valid : std_logic;

                                       
-- FIFO RD SIGNALS
  signal fifoDataIn  : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  signal rdreq : STD_LOGIC;
  signal wrreq : STD_LOGIC;
  signal fifoEmpty : STD_LOGIC;
  signal fifoFull  : STD_LOGIC := '0';
  signal fifoDataOut     : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  signal rd_usedw, wr_usedw : STD_LOGIC_VECTOR(7 downto 0);

  -- FIFO WR SIGNALS
  signal wr_fifoDataIn  : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  signal wr_rdreq : STD_LOGIC;
  signal wr_wrreq : STD_LOGIC;
  signal wr_fifoEmpty : STD_LOGIC;
  signal wr_fifoFull  : STD_LOGIC := '0';
  signal wr_fifoDataOut     : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  
  type read_control_st is (st_idle, st_setup, st_reading, st_finish);
  signal rd_state : read_control_st := st_idle;
	COMPONENT scfifo
	GENERIC (
		add_ram_output_register		: STRING;
		almost_empty_value		: NATURAL;
		almost_full_value		: NATURAL;
		intended_device_family		: STRING;
		lpm_numwords		: NATURAL;
		lpm_showahead		: STRING;
		lpm_type		: STRING;
		lpm_width		: NATURAL;
		lpm_widthu		: NATURAL;
		overflow_checking		: STRING;
		underflow_checking		: STRING;
		use_eab		: STRING
	);
	PORT (
			clock	: IN STD_LOGIC ;
			data	: IN STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
			rdreq	: IN STD_LOGIC ;
			wrreq	: IN STD_LOGIC ;
			almost_empty	: OUT STD_LOGIC ;
			almost_full	: OUT STD_LOGIC ;
			empty	: OUT STD_LOGIC ;
			full	: OUT STD_LOGIC ;
			q	: OUT STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
			usedw	: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
	END COMPONENT;

   --GENERAL SIGNALS
  signal rdcount, wrcount : UNSIGNED(NBITS_COLS + NBITS_LINES-1 downto 0) := (others => '0');
  signal array_size_in, array_size_out : UNSIGNED(31 downto 0) := (others => '0');
  
  signal img_col_size : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal img_line_size : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');
  

  signal kernel           : kernel_type;


  -- SLAVE AVALON
  constant NREGS : integer := 17;
  type reg_type is array (0 to NREGS-1) of std_logic_vector(31 downto 0);
   constant init_registers : reg_type := (
     x"33221100", --id
     x"00000000", --vectorSizeIn
     x"00000000", --vectorSizeOut
     ADDR_BASE_READ, --input pointer
     ADDR_BASE_WRITE, --output pointer,
     x"00000000", -- k[0][0]
     x"00000000", -- k[0][1]
     x"00000000", -- k[0][2]
     x"00000000", -- k[1][0]
     x"00000001", -- k[1][1]
     x"00000000", -- k[1][2]
     x"00000000", -- k[2][0]
     x"00000000", -- k[2][1]
     x"00000000", -- k[2][2]
     x"00000280", -- img_col_size
     x"000001e0", -- img_line_size
     x"00000000" --busy
     );
  signal registers : reg_type := init_registers;
  
begin


-- SLAVE RD/WR
  rd_wr_slave_proc: process (clk, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      start_conv <= '0';
      registers <= init_registers;
    elsif clk'event and clk = '1' then  -- rising clock edge         
      --LEITURA DO SLAVE  ---- READ PROC
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';        
      --ESCRITA NO SLAVE
      elsif slave_write = '1' and slave_chipselect = '1' then
        if unsigned(slave_address) = 0 then
          start_conv <= slave_writedata(0);
          slave_readdatavalid <= '0';
        elsif unsigned(slave_address) < NREGS-1 then
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
      end if;

      if ((wrcount = array_size_out-1 or wrcount = 0) and (rd_state = st_idle)) then
        registers(NREGS-1)(0) <= '0';
      else
        registers(NREGS-1)(0) <= '1';
      end if;

      
    end if;
  end process rd_wr_slave_proc;



  

read_proc: process (clk, rst_n) is
begin  -- process read_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    rdcount <= (others => '0');
    rd_state <= st_idle;
  elsif clk'event and clk = '1' then    -- rising clock edge
    case rd_state is
      when st_idle =>
        rdcount <= (others => '0');
        if ((start_conv = '1' and start_conv_f = '0')) then
          rd_state <= st_setup;
        else
          rd_state <= st_idle;
        end if;

      when st_setup =>
        array_size_in <= unsigned(registers(1));
        array_size_out <= unsigned(registers(2));
        addr_init_rd <= registers(3);
        addr_init_wr <= registers(4);
        
        --kernel values
        kernel(0)(0) <= std_logic_vector(signed(registers(5)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(0)(1) <= std_logic_vector(signed(registers(6)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(0)(2) <= std_logic_vector(signed(registers(7)(NBITS_KERNEL_DATA-1 downto 0)));

        kernel(1)(0) <= std_logic_vector(signed(registers(8)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(1)(1) <= std_logic_vector(signed(registers(9)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(1)(2) <= std_logic_vector(signed(registers(10)(NBITS_KERNEL_DATA-1 downto 0)));

        kernel(2)(0) <= std_logic_vector(signed(registers(11)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(2)(1) <= std_logic_vector(signed(registers(12)(NBITS_KERNEL_DATA-1 downto 0)));
        kernel(2)(2) <= std_logic_vector(signed(registers(13)(NBITS_KERNEL_DATA-1 downto 0)));

        img_col_size <= registers(14)(NBITS_COLS-1 downto 0);
        img_line_size <= registers(15)(NBITS_LINES-1 downto 0);
        
        rd_state <= st_reading;
        

      when st_reading =>
        if masterrd_waitrequest = '0' and s_masterread = '1' then
          if rdcount = array_size_in-1 then
            rd_state <= st_finish;
            rdcount <= (others => '0');
          else
            rdcount <= rdcount + 1;
            rd_state <= st_reading;
          end if;
        else
          rdcount <= rdcount;
          rd_state <= rd_state;
        end if;

      when st_finish =>
        rd_state <= st_idle;
    end case;    
        
  end if;
end process read_proc;


  --- FIFO GET DATA VECTOR  ------------------------------------------------------------
  scfifo_component : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      almost_empty_value => 16,
      almost_full_value => 240,
      intended_device_family => "Cyclone V",
      lpm_numwords => 256,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => NBITS_DATA,
      lpm_widthu => 8,
      overflow_checking => "ON",
      underflow_checking => "ON",
      use_eab => "ON"
      )
    PORT MAP (
      clock => clk,
      data => fifoDataIn,
      rdreq => rdreq,
      wrreq => wrreq,
      almost_empty => open,
      almost_full => open,
      empty => fifoEmpty,
      full => fifoFull,
      q => fifoDataOut,
      usedw => rd_usedw
      );


-- Wiring Avalon MM Read to FifoRD
fifoDataIn <= masterrd_readdata;
s_masterread <= '1' when (rd_state = st_reading) and (UNSIGNED(rd_usedw) < AVALON_MAXIMUM_PENDING_READS-10) else '0';
masterrd_read <= s_masterread;
masterrd_address <= std_logic_vector(rdcount + UNSIGNED(addr_init_rd));
wrreq <= '1' when masterrd_readdatavalid = '1' else '0';
rdreq <= not fifoEmpty and (not wr_fifoFull);


pxl_valid <= rdreq;

window_gen_1: entity work.window_gen
  generic map (
    MAX_COLS    => MAX_COLS,
    NBITS_COLS  => NBITS_COLS,
    NBITS_LINES => NBITS_LINES)
  port map (
    clk          => clk,
    rst_n        => rst_n,
    start_conv   => start_conv,
    pxl_valid    => pxl_valid,
    pxl_data     => fifoDataOut,
    img_col_size => img_col_size,
    img_line_size => img_line_size,
    window_valid => window_valid,
    window_data  => window_data);


conv_core_1: entity work.conv_core
  port map (
    clk              => clk,
    rst_n            => rst_n,
    kernel           => kernel,
    data_in          => window_data,
    data_in_valid    => window_valid,
    pxl_result       => pxl_result,
    pxl_result_valid => pxl_result_valid);



wr_fifoDataIn <= pxl_result;
wr_wrreq <= pxl_result_valid and (not wr_fifoFull);

masterwr_writedata <= wr_fifoDataOut;
s_masterwrite <= '1' when (wr_fifoEmpty = '0') else '0';
masterwr_write <= s_masterwrite;
wr_rdreq <= (not masterwr_waitrequest) and s_masterwrite;
masterwr_address <= std_logic_vector(UNSIGNED(addr_init_wr) + wrcount);

wr_proc: process (clk, rst_n) is
begin  -- process wr_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    wrcount <= (others => '0');
    start_conv_f <= '0';
  elsif clk'event and clk = '1' then    -- rising clock edge
    start_conv_f <= start_conv;
    if (start_conv_f <= '0' and start_conv = '1') then
      wrcount <= (others => '0');
    elsif(wr_rdreq = '1') then      
      wrcount <= wrcount + 1;
    else
      wrcount <= wrcount;
    end if;    
  end if;
end process wr_proc;


  scfifo_component_wr : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      almost_empty_value => 16,
      almost_full_value => 240,
      intended_device_family => "Cyclone V",
      lpm_numwords => 256,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => NBITS_DATA,
      lpm_widthu => 8,
      overflow_checking => "ON",
      underflow_checking => "ON",
      use_eab => "ON"
      )
    PORT MAP (
      clock => clk,
      data => wr_fifoDataIn,
      rdreq => wr_rdreq,
      wrreq => wr_wrreq,
      almost_empty => open,
      almost_full => open,
      empty => wr_fifoEmpty,
      full => wr_fifoFull,
      q => wr_fifoDataOut,
      usedw => wr_usedw
      );

end architecture bhv;
