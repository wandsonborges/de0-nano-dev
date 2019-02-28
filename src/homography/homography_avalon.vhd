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
    HOMOG_DELAY_CYCLES : integer := 8;
    BURST : integer := 8;
    ADDR_READ : std_logic_vector(31 downto 0) := x"38C00000";
    ADDR_WRITE : std_logic_vector(31 downto 0) := x"38500000"
    
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Homography Image
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    --masterwr_burstcount  : out std_logic_vector(NBITS_BURST-1 downto 0);
    

    -- avalon MM Master 2 - Get Raw Image
    masterrd_waitrequest : in std_logic;
    masterrd_readdatavalid : in std_logic;
    masterrd_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd_read       : out std_logic;
    
    -- avalon MM Slave - Configure Homography Matrix
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(3 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0)

    
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
  signal usedw : STD_LOGIC_VECTOR (11 DOWNTO 0);
  signal half_full : STD_LOGIC := '0';
  
  -- HOMOG SIGNALS
  signal inc_addr : STD_LOGIC := '0';
  signal select_homog : STD_LOGIC_VECTOR(31 downto 0);
  signal lastDataFlag : STD_LOGIC := '0';
  signal x_in : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_in : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');

  signal x_out : STD_LOGIC_VECTOR(NBITS_COLS-1 downto 0) := (others => '0');
  signal y_out : STD_LOGIC_VECTOR(NBITS_LINES-1 downto 0) := (others => '0');
 
  -- BUFFER ADDR:
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_WRITE;
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_READ;

  -- MULTIPLIER SIGNALS --> addr = y_out*COLS + x_out + ADDR_BASE
  constant NCOL : std_logic_vector(NBITS_COLS-1 downto 0) := std_logic_vector(to_unsigned(COLS, NBITS_COLS));
  signal mult_result : std_logic_vector(NBITS_COLS+NBITS_LINES-1 downto 0) := (others => '0');
  
  -- AVALON SIGNALS
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_WRITE;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

  --GENERAL SIGNALS
  signal rdcount, wrcount, pxl_count : UNSIGNED(NBITS_COLS+NBITS_LINES-1 downto 0) := (others => '0');  
  signal words_written_during_burst : UNSIGNED(NBITS_BURST-1 downto 0) := (others => '0');

  type wr_control_st is (st_idle, st_write);
  signal state_write, state_write_f : wr_control_st := st_idle;

  --RD PROC SIGNALS
  signal count_delay_cycles : UNSIGNED(7 downto 0) := (others => '0');
  type rd_control_st is (st_waitRq, st_waitHomogDelay, st_wait);
  signal rdstate : rd_control_st := st_wait;
  signal delayCycles : UNSIGNED(31 downto 0) := (others => '0');

  signal pending_counter : UNSIGNED(7 downto 0) := (others => '0');
  constant AVALON_MAXIMUM_PENDING_READS : integer := 16;
  
  -- CONFIGURE HOMOG SIGNALS
  type reg_type is array (0 to 15) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223300", --id
    x"00000020", --nbits_frac
    x"00000000", --matrix select
    x"00100000", --h[0,0]
    x"00000000", --h[0,2]
    x"00000000", --h[0,3]
    x"00000000", --h[1,1]
    x"00100000", --h[1,2]
    x"00000000", --h[1,3]
    x"00000000", --h[2,1]
    x"00000000", --h[2,2]
    x"00100000", --h[2,3]
    x"00000000", --reserved
    x"00000000", --reserved
    x"00000000", --reserved
    x"00000000" --reserved
    );
  signal registers : reg_type := init_registers;
  constant MAT_OFFSET : integer := 3;

 
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
			usedw	: OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
	);
	END COMPONENT;


  
begin  -- architecture bhv

-- AVALON SLAVE: HOMOG CONF
  
 rd_wr_slave_proc: process (clk, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';      
    elsif clk'event and clk = '1' then  -- rising clock edge     
      --LEITURA DO SLAVE  ---- READ PROC
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
      --ESCRITA NO SLAVE
      elsif slave_write = '1' and slave_chipselect = '1' then
        if unsigned(slave_address) > 1 then 
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
      end if;      
    end if;
  end process rd_wr_slave_proc;
  
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
      mat00            => registers(MAT_OFFSET+0),
      mat01            => registers(MAT_OFFSET+1),
      mat02            => registers(MAT_OFFSET+2),
      mat10            => registers(MAT_OFFSET+3),
      mat11            => registers(MAT_OFFSET+4),
      mat12            => registers(MAT_OFFSET+5),
      mat20            => registers(MAT_OFFSET+6),
      mat21            => registers(MAT_OFFSET+7),
      mat22            => registers(MAT_OFFSET+8),
      sw             => select_homog,
      x_out          => x_out,
      y_out          => y_out);
  
-- CHOOSE HOMOG
  select_homog <= registers(2);
  
  -- MULTIPLICA VALOR POR COLS -- COMBINACIONAL
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
      lpm_numwords => 4096,
      lpm_showahead => "ON",
      lpm_type => "scfifo",
      lpm_width => NBITS_DATA+1,
      lpm_widthu => 12,
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

  rd_proc: process (clk, rst_n) is
  begin  -- process rd_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      count_delay_cycles <= (others => '0');
      rdstate <= st_wait;
      delayCycles <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      case rdstate is
        when st_wait =>
          if delayCycles = 50000000*3 then
            rdstate <= st_waitRq;
          else
            delayCycles <= delayCycles + 1;
            rdstate <= st_wait;
          end if;

        when st_waitRq =>
          count_delay_cycles <= (others => '0');
          if masterrd_waitrequest = '0' then
            rdstate <= st_waitHomogDelay;
          else
            rdstate <= st_waitRq;
          end if;

        when st_waitHomogDelay =>          
          if count_delay_cycles = HOMOG_DELAY_CYCLES-1 then
            rdstate <= st_waitRq;            
          else
            count_delay_cycles <= count_delay_cycles + 1;
          end if;

      end case;
        
    end if;
  end process rd_proc;

  inc_addr <= s_masterread and (not masterrd_waitrequest);
  fifoDataIn <= lastDataFlag & masterrd_readdata;
  s_masterread <= '1' when rdstate = st_waitRq and half_full = '0' and pending_counter < AVALON_MAXIMUM_PENDING_READS-1 else '0';
  masterrd_read <= s_masterread;
  masterrd_address <= std_logic_vector(UNSIGNED(mult_result) + UNSIGNED(x_out) + UNSIGNED(ADDR_BASE_READ));
  wrreq <= masterrd_readdatavalid;
 

  half_full <= usedw(11);
 
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


  s_masterwrite <= '1' when fifoEmpty = '0' else '0';
  masterwr_write <= s_masterwrite;
  masterwr_address <= std_logic_vector(wrcount + unsigned(ADDR_BASE_WRITE)); --s_address;
  masterwr_writedata <= fifoDataOut(NBITS_DATA-1 downto 0);
  rdreq <= (not masterwr_waitrequest) and s_masterwrite;
  --masterwr_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));


  pending_proc: process (clk, rst_n) is
  begin  -- process pending_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pending_counter <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (s_masterread = '1' and masterrd_waitrequest = '0' and masterrd_readdatavalid = '1') then
        pending_counter <= pending_counter;
      elsif (s_masterread = '1' and masterrd_waitrequest = '0' and masterrd_readdatavalid = '0') then
        pending_counter <= pending_counter + 1;
      elsif (masterrd_readdatavalid = '1' and pending_counter > 0) then
        pending_counter <= pending_counter - 1;
      else
        pending_counter <= pending_counter;
      end if;

    end if;
  end process pending_proc;
  stwrite_proc: process (clk, rst_n) is
  begin  -- process write_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      state_write <= st_idle;
    elsif clk'event and clk = '1' then  -- rising clock edge
      case state_write is
        when st_idle =>
          if (unsigned(usedw) > 1) then
            state_write <= st_write;
          else
            state_write <= st_idle;
          end if;

        when st_write =>
          if words_written_during_burst = BURST-1 then
            state_write <= st_idle;
          else
            state_write <= st_write;
          end if;
      end case;
      
    end if;
  end process stwrite_proc;


  wrcountProc: process (clk, rst_n) is
  begin  -- process wrcount
    if rst_n = '0' then                 -- asynchronous reset (active low)
      wrcount <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if rdreq = '1' then
        if wrcount = LINES*COLS-1 then
          wrcount <= (others => '0');
        else          
          wrcount <= wrcount + 1;
        end if;
      else
        wrcount <= wrcount;
      end if;      
    end if;
  end process wrcountProc;

  
 --  waitreq_proc: process (clk, rst_n) is
 --  begin  -- process waitreq_proc
 --    if rst_n = '0' then           -- asynchronous reset (active low)
 --      s_address <= ADDR_BASE_WRITE;
 --      words_written_during_burst <= (others => '0');
 --      wrcount <= (others => '0');
 --      pxl_count <= (others => '0');
 --    elsif clk'event and clk = '1' then  -- rising clock edge
 --      -- ADDR UPDATE
 --      if rdreq = '1' then        
 --        if words_written_during_burst = BURST-1 then
 --          words_written_during_burst <= (others => '0');
 --          if (wrcount >= COLS*LINES-1-BURST) and (pxl_count >= COLS*LINES-1) then
 --            s_address <= ADDR_BASE_WRITE;
 --            wrcount <= (others => '0');
 --            pxl_count <= (others => '0');
 --          else
 --            pxl_count <= pxl_count + 1;
 --            wrcount <= wrcount + BURST;
 --            s_address <= std_logic_vector(unsigned(s_address) + BURST);
 --          end if;          
 --        else
 --          pxl_count <= pxl_count + 1;
 --          words_written_during_burst <= words_written_during_burst + 1;            
 --        end if;          
 --      else
 --        words_written_during_burst <= words_written_during_burst;
 --        s_address <= s_address;
 --        pxl_count <= pxl_count;
 --      end if; 
    
 --    end if;
 -- end process waitreq_proc;

  
  
end architecture bhv;
