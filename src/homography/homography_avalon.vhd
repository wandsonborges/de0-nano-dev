library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity homography_avalon is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    HOMOG_BITS_INT : integer := 12;
    HOMOG_BITS_FRAC : integer := 20;
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 8;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Signals
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    

    -- avalon MM Master 2 - Read Signals
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic

    
    );               

end entity homography_avalon;

architecture bhv of homography_avalon is

  -- FIFO SIGNALS
  signal fifoDataIn  : STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
  signal rdreq : STD_LOGIC;
  signal wrreq : STD_LOGIC;
  signal fifoEmpty : STD_LOGIC;
  signal fifoFull  : STD_LOGIC;
  signal fifoDataOut     : STD_LOGIC_VECTOR (NBITS_DATA DOWNTO 0);
  signal usedw : STD_LOGIC_VECTOR (9 DOWNTO 0);
  signal almost_full : STD_LOGIC := '0';
  
  -- HOMOG SIGNALS
  signal inc_addr : STD_LOGIC := '0';
  signal lastDataFlag : STD_LOGIC := '0';
  signal x_in : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_in : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');

  signal x_out : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_out : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');
 
  -- BUFFER ADDR:
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38500000";
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";

  -- MULTIPLIER SIGNALS --> addr = y_out*COLS + x_out + ADDR_BASE
  constant NCOL : std_logic_vector(NBITS_COLS-1 downto 0) := std_logic_vector(to_unsigned(COLS, NBITS_COLS));
  signal mult_result : std_logic_vector(NBITS_COLS+NBITS_LINES-1 downto 0) := (others => '0');
  
  -- AVALON SIGNALS
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_WRITE;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

  --GENERAL SIGNALS
  signal rdcount : UNSIGNED(NBITS_COLS+NBITS_LINES-1 downto 0) := (others => '0');


  -- STATE MACHINES
 
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
			dataa	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			datab	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			result	: OUT STD_LOGIC_VECTOR (23 DOWNTO 0)
	);
	END COMPONENT;
  

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
			usedw	: OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
	);
	END COMPONENT;


  
begin  -- architecture bhv

  homography_core_1: entity work.homography_core
    generic map (
      WIDTH           => COLS,
      HEIGHT          => LINES,
      CICLOS_LATENCIA => 8,
      WW              => NBITS_COLS,
      HW              => NBITS_LINES,
      n_bits_int      => HOMOG_BITS_INT,
      n_bits_frac     => HOMOG_BITS_FRAC)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      x_in           => x_in,
      y_in           => y_in,
      inc_addr       => inc_addr,
      last_data      => open,
      sw             => (others => '0'),
      x_out          => x_out,
      y_out          => y_out);

  -- MULTIPLICA VALOR POR COLS EM 1 CICLO
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
  scfifo_component : scfifo
    GENERIC MAP (
      add_ram_output_register => "OFF",
      intended_device_family => "Cyclone V",
      lpm_numwords => 1024,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => NBITS_DATA+1,
      lpm_widthu => 10,
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
      usedw => open
      );

  inc_addr <= s_masterread and (not masterrd_waitrequest);
  fifoDataIn <= lastDataFlag & masterrd_readdata;
  s_masterread <= not fifoFull;
  masterrd_read <= s_masterread;
  masterrd_address <= std_logic_vector(UNSIGNED(mult_result) + UNSIGNED(x_out) + UNSIGNED(ADDR_BASE_READ));
  wrreq <= masterrd_readdatavalid and (not fifoFull);
 

  almost_full <= usedw(9) and usedw(8);
 
xy_gen: process (clk, rst_n) is
begin  -- process xy_gen
  if rst_n = '0' then                   -- asynchronous reset (active low)
    x_in <= (others => '0');
    y_in <= (others => '0');
    rdcount <= (others => '0');
    lastDataFlag <= '0';
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

    -- GENERATE END OF FRAME FLAG
    if masterrd_readdatavalid = '1' then
      if rdcount = COLS*LINES-1 then
        rdcount <= (others => '0');
      else
        rdcount <= rdcount + 1;
      end if;
      if rdcount = COLS*LINES-2 then
        lastDataFlag <= '1';
      else
        lastDataFlag <= '0';
      end if;
    end if;    
  end if;
end process xy_gen;


  s_masterwrite <= not fifoEmpty;
  masterwr_write <= s_masterwrite;
  masterwr_address <= s_address;
  masterwr_writedata <= fifoDataOut(NBITS_DATA-1 downto 0);
  rdreq <= (not masterwr_waitrequest) and s_masterwrite;

  waitreq_proc: process (clk, rst_n) is
  begin  -- process waitreq_proc
    if rst_n = '0' then           -- asynchronous reset (active low)
      s_address <= ADDR_BASE_WRITE;
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- ADDR UPDATE
      if rdreq = '1' then
        if fifoDataOut(NBITS_DATA) = '1' then --endofpacket received
          s_address <= ADDR_BASE_WRITE;
        else
          s_address <= std_logic_vector(unsigned(s_address) + 1);                
        end if;
      else
        s_address <= s_address;
      end if; 
      
    end if;
  end process waitreq_proc;

  
end architecture bhv;
