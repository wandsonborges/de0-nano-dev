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

    -- controller input signals
    enable_read : in std_logic;    
    packets_to_read : in std_logic_vector(NBITS_PACKETS-1 downto 0);
    address_init : in std_logic_vector(NBITS_ADDR-1 downto 0);

    -- data request signals
    get_read_data : out std_logic;
    data_ready : out std_logic;
    data_out : out std_logic_vector(NBITS_DATA-1 downto 0);
    burst_en : out std_logic
    );               

end entity readPacketsAvalon;

architecture bhv of readPacketsAvalon is

  -- FIFO SIGNALS
  signal fifoDataIn  : STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
  signal rdreq : STD_LOGIC;
  signal wrreq : STD_LOGIC;
  signal fifoEmpty : STD_LOGIC;
  signal fifoFull  : STD_LOGIC;
  signal fifoDataOut     : STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
  signal usedw : STD_LOGIC_VECTOR (7 DOWNTO 0);
  signal half_full : STD_LOGIC := '0';
  
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
  signal req_read, running : std_logic := '0';

  --READ PARAMETER STATE MACHINE
  type read_control_st is (st_idle, st_setup, st_reading, st_finish);
  signal state : read_control_st := st_idle;
  
  
  	COMPONENT scfifo
	GENERIC (
		add_ram_output_register		: STRING;
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
			data	: IN STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
			rdreq	: IN STD_LOGIC ;
			wrreq	: IN STD_LOGIC ;
			empty	: OUT STD_LOGIC ;
			full	: OUT STD_LOGIC ;
			q	: OUT STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
			usedw	: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
	END COMPONENT;


  
begin  -- architecture bhv


  --- FIFO GET DATA VECTOR  ------------------------------------------------------------
  scfifo_component_1 : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      intended_device_family => "Cyclone V",
      lpm_numwords => FIFO_SIZE,
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
      empty => fifoEmpty,
      full => fifoFull,
      q => fifoDataOut,
      usedw => usedw
      );


  fifoDataIn <= masterrd_readdata;
  s_masterread <= '1' when fifoFull = '0' and (state = st_reading);
  masterrd_read <= s_masterread;
  masterrd_address <= std_logic_vector(UNSIGNED(rdcount) + UNSIGNED(address_init_flop));
  wrreq <= masterrd_readdatavalid; 


  data_out <= fifoDataOut;
  get_read_data <= rdreq;
  data_ready <= not fifoEmpty;
  half_full <= usedw(7);
 
  
countProc: process (clk, rst_n) is
  begin  -- process countProc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      rdcount <= (others => '0');
      packets_to_read_flop <= (others => '0');
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
          if wrreq = '1' then
            rdcount <= rdcount + 1;
            if rdcount = packets_to_read_flop-1 then
              state <= st_finish;
            else              
              state <= st_reading;
            end if;
          else
            rdcount <= rdcount;
            state <= st_reading;
          end if;

        when st_finish =>
          state <= st_idle;
           
          
      end case;
      
    end if;
    
  end process countProc;  

  
end architecture bhv;
