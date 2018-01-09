library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity readPacketsAvalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 8;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12;
    CICLOS_LATENCIA : integer := 8;
    COLS : integer := 640;
    LINES : integer := 480;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 256;
    BURST : integer := 8
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
    
    -- avalon MM Master - Get  Vector 
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic;

    -- controller input signals
    enable_read : in std_logic;    
    packets_to_read : in std_logic_vector(NBITS_PACKETS-1 downto 0);
    address_init : in std_logic_vector(NBITS_ADDR-1 downto 0);
    get_read_data : in std_logic;
    
    -- data request signals    
    data_ready : out std_logic;
    data_out : out std_logic_vector(NBITS_DATA-1 downto 0);
    burst_en : out std_logic
    );               

end entity readPacketsAvalon;

architecture bhv of readPacketsAvalon is

  -- FIFO SIGNALS
  signal fifoDataIn  : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  signal rdreq : STD_LOGIC;
  signal wrreq : STD_LOGIC;
  signal fifoEmpty : STD_LOGIC;
  signal fifoFull, almost_full  : STD_LOGIC := '0';
  signal fifoDataOut     : STD_LOGIC_VECTOR (NBITS_DATA-1 DOWNTO 0);
  signal usedw : STD_LOGIC_VECTOR (7 DOWNTO 0);
  signal  fifo_count : UNSIGNED (7 DOWNTO 0);
  signal half_full : STD_LOGIC := '0';


    -- FIFO ADDR SIGNALS
  signal addr_fifoDataIn  : STD_LOGIC_VECTOR (NBITS_COLS+NBITS_LINES-1 DOWNTO 0);
  signal addr_rdreq : STD_LOGIC;
  signal addr_wrreq : STD_LOGIC;
  signal addr_fifoEmpty : STD_LOGIC;
  signal addr_fifoFull : STD_LOGIC := '0';
  signal addr_fifoDataOut     : STD_LOGIC_VECTOR (NBITS_COLS+NBITS_LINES-1 DOWNTO 0);


  -- AVALON SIGNALS

  constant ADDR_BASE_READ_INIT : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";

  signal s_address, address_init_flop : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_READ_INIT;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

  --GENERAL SIGNALS
  signal rdcount : UNSIGNED(NBITS_PACKETS-1 downto 0) := (others => '0');
  signal packets_to_read_flop : UNSIGNED(NBITS_PACKETS-1 downto 0) := (others => '0');
  signal enable_read_f : std_logic := '0';
  
  --CONTROL SIGNAL
  signal start_op, start_op_f : std_logic := '0';
  signal req_read, running, inc_addr : std_logic := '0';
  signal enable_mread, enable_mreadvalid : std_logic := '0';

  
  -- MULTIPLIER SIGNALS --> addr = y_out*COLS + x_out + ADDR_BASE
  constant NCOL : std_logic_vector(NBITS_COLS-1 downto 0) := std_logic_vector(to_unsigned(COLS, NBITS_COLS));
  signal mult_result : std_logic_vector(NBITS_COLS+NBITS_LINES-1 downto 0) := (others => '0');

  signal x_in : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_in : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');

  signal x_out, x_out_valid : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_out, y_out_valid : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');

  signal addr_valid : std_logic := '0';
  --READ PARAMETER STATE MACHINE
  type read_control_st is (st_idle, st_setup, st_reading, st_finish);
  signal state : read_control_st := st_idle;
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

COMPONENT lpm_mult
	GENERIC (
		lpm_hint		: STRING;
		lpm_representation		: STRING;
		lpm_type		: STRING;
		lpm_widtha		: NATURAL;
		lpm_widthb		: NATURAL;
		lpm_widthp		: NATURAL
	);
	PORT (
			dataa	: IN STD_LOGIC_VECTOR (NBITS_LINES-1 DOWNTO 0);
			datab	: IN STD_LOGIC_VECTOR (NBITS_COLS-1 DOWNTO 0);
			result	: OUT STD_LOGIC_VECTOR (NBITS_LINES+NBITS_COLS-1 DOWNTO 0)
	);
	END COMPONENT;
  
begin  -- architecture bhv

  lpm_mult_component : lpm_mult
	GENERIC MAP (
		lpm_hint => "INPUT_B_IS_CONSTANT=YES,DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5",
		lpm_representation => "UNSIGNED",
		lpm_type => "LPM_MULT",
		lpm_widtha => NBITS_LINES,
		lpm_widthb => NBITS_COLS,
		lpm_widthp => NBITS_LINES+NBITS_COLS
	)
	PORT MAP (
		dataa => y_out,
		datab => NCOL,
		result => mult_result
	);

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
      lpm_widthu => 8, --PARAMETRIZAR ISSO AQUI!
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
      almost_full => almost_full,
      empty => fifoEmpty,
      full => fifoFull,
      q => fifoDataOut,
      usedw => usedw
      );



  fifoDataIn <= masterrd_readdata;
  s_masterread <= '1' when fifoFull = '0' and addr_fifoEmpty = '0' and (state = st_reading) else '0';
  masterrd_read <= addr_valid;
  masterrd_address <= std_logic_vector(UNSIGNED(mult_result) + UNSIGNED(x_out) + UNSIGNED(address_init_flop));
  wrreq <= '1' when (masterrd_readdatavalid = '1') else '0';


  data_out <= fifoDataOut;
  rdreq <= get_read_data;
  data_ready <= not fifoEmpty;
  half_full <= usedw(7);
  
countProc: process (clk, rst_n) is
  begin  -- process countProc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      rdcount <= (others => '0');
      packets_to_read_flop <= (others => '0');
      rdcount <= (others => '0');
      s_address <= ADDR_BASE_READ_INIT;
    elsif clk'event and clk = '1' then  -- rising clock edge
      enable_read_f <= enable_read;
      
      if UNSIGNED(usedw) >= BURST then
        burst_en <= '1';
      else
        burst_en <= '0';
      end if;
      
      case state is
        when st_idle =>
          packets_to_read_flop <= (others => '0');
          rdcount <= (others => '0');
          address_init_flop <= ADDR_BASE_READ_INIT;
          if enable_read = '1' and enable_read_f = '0' then
            state <= st_setup;
          else
            state <= st_idle;
          end if;

        when st_setup =>
          packets_to_read_flop <= UNSIGNED(packets_to_read);
          rdcount <= (others => '0');
          address_init_flop <= address_init;
          state <= st_reading;

        when st_reading =>
          if rdcount = packets_to_read_flop-1 then
            state <= st_finish;
            rdcount <= (others => '0');
          elsif masterrd_waitrequest = '0' and s_masterread = '1' then
            rdcount <= rdcount + 1;
            state <= st_reading;
          else
            state <= st_reading;
            rdcount <= rdcount;
          end if;
                  
        when st_finish =>
          state <= st_idle;
           
          
      end case;
      
    end if;
    
  end process countProc;  

  xy_gen: process (clk, rst_n) is
begin  -- process xy_gen
  if rst_n = '0' then                   -- asynchronous reset (active low)
    x_in <= (others => '0');
    y_in <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    if inc_addr = '1' then
      if (unsigned(x_in) = COLS-1 and unsigned(y_in) = LINES-1) then
        x_in <= (others => '0');
        y_in <= (others => '0');
      elsif (unsigned(x_in) = COLS-1) then
        x_in <= (others => '0');
        y_in <= std_logic_vector(unsigned(y_in) + 1);
      else
        x_in <= std_logic_vector(unsigned(x_in) + 1);
      end if;      
    end if;
end if;

end process xy_gen;


  homography_core_1: entity work.homography_core
    generic map (
      WIDTH           => COLS,
      HEIGHT          => LINES,
      CICLOS_LATENCIA => CICLOS_LATENCIA,
      WW              => NBITS_COLS,
      HW              => NBITS_LINES,
      n_bits_int      => 12,
      n_bits_frac     => 20)
    port map (
      clk       => clk,
      rst_n     => rst_n,
      inc_addr  => inc_addr, 
      sw        => x"00000002",
      x_in      => x_in,
      y_in      => y_in,
      last_data => open,
      mat00     => (others => '0'),
      mat01     => (others => '0'),
      mat02     => (others => '0'),
      mat10     => (others => '0'),
      mat11     => (others => '0'),
      mat12     => (others => '0'),
      mat20     => (others => '0'),
      mat21     => (others => '0'),
      mat22     => (others => '0'),
      addr_valid => addr_valid,
      x_out     => x_out_valid,
      y_out     => y_out_valid);


-- FIFO ADDR
    scfifo_component_addr : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      almost_empty_value => 16,
      almost_full_value => FIFO_SIZE-16,
      intended_device_family => "Cyclone V",
      lpm_numwords => 64,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => NBITS_COLS + NBITS_LINES,
      lpm_widthu => 6, --PARAMETRIZAR ISSO AQUI!
      overflow_checking => "ON",
      underflow_checking => "ON",
      use_eab => "ON"
      )
    PORT MAP (
      clock => clk,
      data => addr_fifoDataIn,
      rdreq => addr_rdreq,
      wrreq => addr_wrreq,
      empty => addr_fifoEmpty,
      full => addr_fifoFull,
      q => addr_fifoDataOut,
      usedw => open
      );

  addr_fifoDataIn <= y_out_valid & x_out_valid;
  inc_addr <= not addr_fifoFull;
  addr_rdreq <= s_masterread and (not masterrd_waitrequest);
  x_out <= addr_fifoDataOut(NBITS_COLS-1 downto 0);
  y_out <= addr_fifoDataOut(NBITS_LINES + NBITS_COLS-1 downto NBITS_COLS);
  addr_wrreq <= addr_valid;

end architecture bhv;
