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
    slave_address       : in std_logic_vector(0 downto 0);
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
  type reg_type is array (0 to 1) of std_logic_vector(31 downto 0);
  signal registers : reg_type := (
    x"11223344",
    x"55667788"
    );

  -- type reg_type is array (0 to 10) of std_logic_vector(31 downto 0);
  -- signal registers : reg_type := (
  --   x"11223344",
  --   x"0000FFCB",
  --   x"00000037",
  --   x"00000037",
  --   x"00000037",
  --   x"00000005",
  --   x"00000006",
  --   x"00000007",
  --   x"00000008",
  --   x"00000009",
  --   x"0000000A"
  --   );

  constant ADDR_BASE_BUF0 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF;
  constant ADDR_BASE_BUF1 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF;
  --constant ADDR_BASE_BUF1 : std_logic_vector(NBITS_ADDR-1 downto 0) :=
  --x"38500000"; --TROCAR!!
  
  signal fifoDataIn : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoDataOut : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoFull, fifoEmpty : std_logic := '0';
  signal fifoWr, fifoRd : std_logic := '0';
  signal rdusedw : std_logic_vector (11 downto 0) := (others => '0');
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_BUF0;
  signal s_masterwrite : std_logic := '0';
  signal s_master_writedata : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');

  signal buffer_update : std_logic := '0';

  type BUF_TYPE is (buffer_0, buffer_1, none);
  signal buffer_write : BUF_TYPE := buffer_1;
  signal buffer_read : BUF_TYPE := none;
  signal last_buffer_read : BUF_TYPE := buffer_1;

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

  rd_wr_slave_proc: process (clk_mem, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      request_read <= '0';
    elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
      --LEITURA DO SLAVE
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
      --ESCRITA NO SLAVE
      elsif slave_write = '1' and slave_chipselect = '1' then
        request_read <= slave_writedata(0);
        slave_readdatavalid <= '0';
      else
        slave_readdatavalid <= '0';
      end if;      
    end if;
  end process rd_wr_slave_proc;


  -- state_proc: process (clk_mem, rst_n) is
  -- begin  -- process state_proc
  --   if rst_n = '0' then                 -- asynchronous reset (active low)
  --     state <= st_idle;
  --     buffer_read <= none;
  --     registers <= (x"11223344", x"55667788");
  --     last_buffer_read <= buffer_1;
  --   elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
  --         ---- STATE MACHINE
  --   case state is
  --     when st_idle =>
  --       registers(1) <= (others => '0');
  --       buffer_read <= none;
  --       if request_read = '1' then
  --         state <= st_define;
  --       else
  --         state <= st_idle;
  --       end if;

  --     when st_define =>
  --       registers(1) <= (others => '0');
  --       buffer_read <= none;
  --       if last_buffer_read = buffer_1 then
  --         state <= st_lockB0;
  --       else
  --         state <= st_lockB1;
  --       end if;        

  --     when st_lockB0 =>
  --       buffer_read <= none;
  --       registers(1) <= (others => '0');
  --       if buffer_write = buffer_0 then
  --         state <= st_lockB0;
  --       else
  --         state <= st_waitFreeB0;
  --       end if;

  --     when st_waitFreeB0 =>
  --       buffer_read <= buffer_0;
  --       last_buffer_read <= buffer_0;
  --       registers(1) <= x"00000001";
  --       registers(0) <= ADDR_BASE_BUF0;
  --       if request_read = '0' then
  --         state <= st_idle;
  --       else
  --         state <= st_waitFreeB0;
  --       end if;

  --     when st_lockB1 =>
  --       registers(1) <= (others => '0');
  --       buffer_read <= none;
  --       if buffer_write = buffer_1 then
  --         state <= st_lockB1;
  --       else
  --         state <= st_waitFreeB1;
  --       end if;

  --     when st_waitFreeB1 =>
  --       buffer_read <= buffer_1;
  --       last_buffer_read <= buffer_1;
  --       registers(1) <= x"00000001";
  --       registers(0) <= ADDR_BASE_BUF1;
  --       if request_read = '0' then
  --         state <= st_idle;
  --       else
  --         state <= st_waitFreeB1;
  --       end if;
        
  --   end case;
  --   end if;
  -- end process state_proc;

  req_buffer_proc: process (clk_mem, rst_n) is
begin  -- process slave_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    buffer_read <= none;
  elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
    if request_read = '1' then
      if buffer_write = buffer_0 then
        buffer_read <= buffer_1;
        registers(0) <= ADDR_BASE_BUF1;
      else
        buffer_read <= buffer_0;
        registers(0) <= ADDR_BASE_BUF0;
      end if;
      registers(1) <= x"00000000";
    else
      buffer_read <= none;
      registers(1) <= x"00000001";
    end if;   
  end if;
end process req_buffer_proc;



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
    buffer_write <= buffer_1;
    words_written_during_burst <= (others => '0');
  elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
    -- ADDR UPDATE
    if s_masterwrite = '1' and master_waitrequest = '0' then
      if fifoDataOut(NBITS_DATA+1) = '1' then --endofpacket received
        if (buffer_read = none) then --nao ha leitura, buffer ping
                                               --pong corre livre
          if buffer_write = buffer_1 then 
            buffer_write <= buffer_0;
            s_address <= ADDR_BASE_BUF0;
          else
            buffer_write <= buffer_1;
            s_address <= ADDR_BASE_BUF1;
          end if;
        elsif buffer_read = buffer_1 then --buffer1 sendo lido
          buffer_write <= buffer_0;
          s_address <= ADDR_BASE_BUF0; 
        else  --buffer0 sendo lido
          buffer_write <= buffer_1;  
          s_address <= ADDR_BASE_BUF1; 
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

master_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));

--AVALON MM Slave ASSIGMENTS
--slave_waitrequest <= '0';        

end architecture bhv;
