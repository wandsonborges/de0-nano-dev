library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity readPacketsAvalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 32;
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
    masterrd_burstcount : out std_logic_vector(3 downto 0);

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
  signal fifo_count : UNSIGNED (31 DOWNTO 0);
  signal fifoOverflow : STD_LOGIC := '0';
  signal fifoUnderflow : STD_LOGIC := '0';
  signal half_full : STD_LOGIC := '0';
  
  -- AVALON SIGNALS

  constant ADDR_BASE_READ_INIT : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";
  constant AVALON_MAXIMUM_PENDING_READS : integer := 7;
  
  signal s_address, address_init_flop : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_READ_INIT;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

  --GENERAL SIGNALS
  signal rdcount : UNSIGNED(NBITS_PACKETS-1 downto 0) := (others => '0');
  signal packets_to_read_flop : UNSIGNED(NBITS_PACKETS-1 downto 0) := (others => '0');
  signal enable_read_f : std_logic := '0';
  
  --CONTROL SIGNAL
  signal start_op, start_op_f : std_logic := '0';
  signal req_read, running : std_logic := '0';
  signal enable_mread, enable_mreadvalid : std_logic := '0';

  signal pending_counter : UNSIGNED(15 downto 0) := (others => '0');


  --signal fifo_count : UNSIGNED(31 downto 0) := (others => '0');

  constant WAIT_CYCLES : integer := 50000000*3;
  signal waitCounter : unsigned(31 downto 0) := (others => '0');
  --READ PARAMETER STATE MACHINE
  type read_control_st is (st_wait, st_idle, st_setup, st_reading, st_finish);
  signal state : read_control_st := st_wait;
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

  
begin  -- architecture bhv


  --- FIFO GET DATA VECTOR  ------------------------------------------------------------
  scfifo_component : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      almost_empty_value => 16,
      almost_full_value => 64,
      intended_device_family => "Cyclone V",
      lpm_numwords => 256,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => 32,
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
      almost_full => almost_full,
      empty => fifoEmpty,
      full => fifoFull,
      q => fifoDataOut,
      usedw => usedw
      );


  fifoDataIn <= masterrd_readdata;
  s_masterread <= '1' when (pending_counter < AVALON_MAXIMUM_PENDING_READS) and (state = st_reading) and (fifo_count < 240) and (fifoOverflow = '0') and (fifoUnderflow = '0') else '0';
  masterrd_read <= s_masterread;
  masterrd_address <= std_logic_vector((rdcount sll 2) + UNSIGNED(address_init_flop));
  masterrd_burstcount <= std_logic_vector(to_unsigned(BURST, masterrd_burstcount'length));
  wrreq <= '1' when (masterrd_readdatavalid = '1' and pending_counter > 0) else '0';


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
      state <= st_wait;
    elsif clk'event and clk = '1' then  -- rising clock edge
      enable_read_f <= enable_read;

      --data_ready <= not fifoEmpty;
      
      if UNSIGNED(usedw) >= BURST then
        burst_en <= '1';
      else
        burst_en <= '0';
      end if;
      
      case state is
        when st_wait =>
          if (waitCounter = WAIT_CYCLES-1) then
            waitCounter <= waitCounter;
            state <= st_idle;
          else
            waitCounter <= waitCounter + 1;
            state <= st_wait;
          end if;
          
        when st_idle =>
          packets_to_read_flop <= (others => '0');
          rdcount <= (others => '0');
          address_init_flop <= ADDR_BASE_READ_INIT;
          if enable_read = '1' then --and enable_read_f = '0' then
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
          if rdcount >= packets_to_read_flop then
            state <= st_finish;
            --rdcount <= (others => '0');
          elsif masterrd_waitrequest = '0' and s_masterread = '1' then
            rdcount <= rdcount + BURST;
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


  pending_process: process (clk, rst_n) is
  begin  -- process pending_process
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pending_counter <= (others => '0');
      fifo_count <= (others => '0');
      fifoOverflow <= '0';
      fifoUnderflow <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (s_masterread = '1' and masterrd_waitrequest = '0' and masterrd_readdatavalid = '1') then
        pending_counter <= pending_counter + BURST - 1;
      elsif (s_masterread = '1' and masterrd_waitrequest = '0' and masterrd_readdatavalid = '0') then
        pending_counter <= pending_counter + BURST;
      elsif (masterrd_readdatavalid = '1' and pending_counter > 0) then
        pending_counter <= pending_counter - 1;
      else
        pending_counter <= pending_counter;
      end if;

      if (rdreq = '1' and wrreq = '1') then
        fifo_count <= fifo_count;
      elsif (rdreq = '1' and wrreq = '0') then
        fifo_count <= fifo_count - 1;
      elsif (rdreq = '0' and wrreq = '1') then
        fifo_count <= fifo_count + 1;
      else
        fifo_count <= fifo_count;
      end if;

      if (fifo_count = 0 and rdreq = '1') then
        fifoUnderflow <= '1';
      else
        fifoUnderflow <= fifoUnderflow;
      end if;

      if (fifo_count = 255 and wrreq = '1') then
        fifoOverflow <= '1';
      else
        fifoOverflow <= fifoOverflow;
      end if;

      
    
    end if;
  end process pending_process;

  
end architecture bhv;
