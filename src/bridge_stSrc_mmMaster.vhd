library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity bridge_stSrc_mmMaster is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 8;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8;
    ADDR_BASE_BUF : std_logic_vector(31 downto 0) := x"38000000"    
    );

  port (
    --clk and reset_n
    clk, clk_mem, rst_n : in std_logic;

    -- avalon MM Slave
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(1 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0);
    
    -- avalon MM Master    
    master_waitrequest : in std_logic;
    master_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    master_write       : out std_logic;
    master_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    master_burstcount   : out std_logic_vector(NBITS_BURST-1 downto 0);
    
    -- avalon ST Sink
    st_startofpacket : in std_logic;
    st_endofpacket   : in std_logic;
    st_datain        : in std_logic_vector(NBITS_DATA-1 downto 0);
    st_datavalid     : in std_logic;
    st_ready         : out std_logic
    
    );               

end entity bridge_stSrc_mmMaster;

architecture bhv of bridge_stSrc_mmMaster is
  --REGS
  --0 (32 bits), somente leitura: endereço do buffer a ser lido
  --1 (32 bits), somente escrita: requisição de buffer (manter em 1 enquanto
  --estiver lendo)
  type reg_type is array (0 to 3) of std_logic_vector(31 downto 0);
  signal registers : reg_type := (
    x"11223344", -- id
    x"00000001", -- frame disponivel para ser lido (0, 1 ou 2)
    x"00014000", -- frameSize
    x"00000000" -- reading
    );

  constant BUFFER_TO_READ_INDEX : integer := 1;
  constant FRAME_SIZE_INDEX : integer := 2;
  constant READING_BUFFER_INDEX : integer := 3;
  

  signal FRAME_SIZE : unsigned(31 downto 0) := x"00014000";

  signal cpuIsReading, cpuIsReading_f : std_logic := '0';
  
  constant ADDR_BASE_BUF0 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF;
  signal ADDR_BASE_BUF1 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF;
  signal ADDR_BASE_BUF2 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF;
  
  signal fifoDataIn : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoDataOut : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoFull, fifoEmpty : std_logic := '0';
  signal fifoWr, fifoRd : std_logic := '0';
  signal rdusedw : std_logic_vector (11 downto 0) := (others => '0');
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF0;
  signal s_masterwrite : std_logic := '0';
  signal s_master_writedata : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');

  signal buffer_update : std_logic := '0';

  type BUF_TYPE is (buffer_0, buffer_1, buffer_2, none);
  signal buffer_write : BUF_TYPE := buffer_1;
  signal buffer_read, last_buffer_ready : BUF_TYPE := none;

  type db_state is (st_idle, st_define, st_lockB1, st_lockB0, st_waitFreeB0, st_waitFreeB1);
  signal state : db_state := st_idle;
  signal request_read : std_logic := '0';


  --write state
  type wr_control_st is (st_idle, st_write);
  signal state_write : wr_control_st := st_idle;

  signal words_written_during_burst : unsigned(NBITS_BURST-1 downto 0) := (others => '0');

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
			rdusedw	: OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
			wrfull	: OUT STD_LOGIC 
	);
	END COMPONENT;

  
begin  -- architecture bhv

  
  FRAME_SIZE <= unsigned(registers(FRAME_SIZE_INDEX));
  ADDR_BASE_BUF1 <= std_logic_vector(to_unsigned(to_integer(unsigned(ADDR_BASE_BUF) + FRAME_SIZE),ADDR_BASE_BUF'length));
  ADDR_BASE_BUF2 <= std_logic_vector(to_unsigned(to_integer(unsigned(ADDR_BASE_BUF) + 2*FRAME_SIZE),ADDR_BASE_BUF'length));

  cpuIsReading <= registers(READING_BUFFER_INDEX)(0);

  rd_wr_slave_proc: process (clk_mem, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      request_read <= '0';
      cpuIsReading_f <= '0';
    elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge

      cpuIsReading_f <= cpuIsReading;
   
      
      --LEITURA DO SLAVE
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
        --ESCRITA NO SLAVE
      elsif slave_write = '1' and slave_chipselect = '1' then
        if unsigned(slave_address) > BUFFER_TO_READ_INDEX then 
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
        if cpuIsReading = '1' and cpuIsReading_f = '0' then
          buffer_read <= last_buffer_ready;
          if (last_buffer_ready = buffer_2) then
            registers(BUFFER_TO_READ_INDEX) <= x"00000002";
          elsif (last_buffer_ready = buffer_1) then
            registers(BUFFER_TO_READ_INDEX) <= x"00000001";
          else
            registers(BUFFER_TO_READ_INDEX) <= x"00000000";
          end if;
          
        elsif cpuIsReading = '0' then
          buffer_read <= none;
        else
          buffer_read <= buffer_read;
        end if;
        
      end if;      
    end if;
  end process rd_wr_slave_proc;




----- ---  BUFFER PING-PONG WRITE ROUTINE ------------------
 
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
        	data => fifoDataIn,
        	rdclk => clk_mem,
        	rdreq => fifoRd,
        	wrclk => clk,
        	wrreq => fifoWr,
        	q => fifoDataOut,
        	rdempty => fifoEmpty,
                rdusedw => rdusedw,
        	wrfull => fifoFull
	);


waitreq_proc: process (clk_mem, rst_n) is
begin  -- process waitreq_proc
  if rst_n = '0' then           -- asynchronous reset (active low)
    s_address <= ADDR_BASE_BUF1;
    last_buffer_ready <= buffer_1;
    words_written_during_burst <= (others => '0');
  elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
    -- ADDR UPDATE
    if s_masterwrite = '1' and master_waitrequest = '0' then
      if fifoDataOut(NBITS_DATA+1) = '1' then --endofpacket received

        last_buffer_ready <= buffer_write;     
          
        
        if (buffer_read = none) then --nao ha leitura, buffer ping
                                               --pong corre livre
          if buffer_write = buffer_0 then 
            buffer_write <= buffer_1;
            s_address <= ADDR_BASE_BUF1;
          elsif buffer_write = buffer_1 then
            buffer_write <= buffer_2;
            s_address <= ADDR_BASE_BUF2;
          else
            buffer_write <= buffer_0;
            s_address <= ADDR_BASE_BUF0;
          end if;
          
        elsif buffer_read = buffer_1 then --buffer1 sendo lido
          if buffer_write = buffer_0 then 
            buffer_write <= buffer_2;
            s_address <= ADDR_BASE_BUF2;
          else
            buffer_write <= buffer_0;
            s_address <= ADDR_BASE_BUF0;
          end if;

        elsif buffer_read = buffer_0 then --buffer0 sendo lido
          if buffer_write = buffer_2 then 
            buffer_write <= buffer_1;
            s_address <= ADDR_BASE_BUF1;
          else
            buffer_write <= buffer_2;
            s_address <= ADDR_BASE_BUF2;
          end if;

        else  --buffer2 sendo lido
          if buffer_write = buffer_1 then 
            buffer_write <= buffer_0;
            s_address <= ADDR_BASE_BUF0;
          else
            buffer_write <= buffer_1;
            s_address <= ADDR_BASE_BUF1;
          end if;
        end if;
        words_written_during_burst <= (others => '0');
      else
        if words_written_during_burst = BURST-1 then
          words_written_during_burst <= (others => '0');
          s_address <= std_logic_vector(unsigned(s_address) + BURST);
        else
          words_written_during_burst <= words_written_during_burst + 1;
        end if;        
      end if;
    else
      s_address <= s_address;
    end if; 
    
  end if;
end process waitreq_proc;


  stwrite_proc: process (clk_mem, rst_n) is
  begin  -- process write_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      state_write <= st_idle;
    elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
      case state_write is
        when st_idle =>
          if (unsigned(rdusedw) > BURST) then
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

  
--AVALON ST<->MM Master ASSIGMENTS        
fifoDataIn <= st_endofpacket & st_startofpacket & st_datain;
fifoWr <= st_datavalid and (not fifoFull);
fifoRd <= (not master_waitrequest) and (s_masterwrite);        
st_ready <= not fifoFull;

s_masterwrite <= '1' when state_write = st_write else '0'; --not fifoEmpty;

master_write <= s_masterwrite;
master_address <= s_address;
master_writedata <= fifoDataOut(NBITS_DATA-1 downto 0);
  -- master_writedata <= (others => '0') when buffer_write = buffer_0 else
  --                     (others => '1') when buffer_write = buffer_1 else
  --                     x"7F" when buffer_write = buffer_2;

master_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));

--AVALON MM Slave ASSIGMENTS
--slave_waitrequest <= '0';        

end architecture bhv;
