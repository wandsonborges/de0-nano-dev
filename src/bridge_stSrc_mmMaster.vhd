library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity bridge_stSrc_mmMaster is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    NBITS_ADDR : integer := 32;
    NBITS_DATA : integer := 8;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8
    );

  port (
    --clk and reset_n
    clk, clk_mem, rst_n : in std_logic;
    
    -- avalon MM Master    
    master_waitrequest : in std_logic;
    master_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    --master_byteenable  : out std_logic_vector(NBITS_BYTEEN-1 downto 0);
    --master_burstcount  : out std_logic_vector(NBITS_BURST-1 downto 0);
    master_write       : out std_logic;
    master_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    
    -- avalon ST Sink
    st_startofpacket : in std_logic;
    st_endofpacket   : in std_logic;
    st_datain        : in std_logic_vector(NBITS_DATA-1 downto 0);
    st_datavalid     : in std_logic;
    st_ready         : out std_logic
    
    );               

end entity bridge_stSrc_mmMaster;

architecture bhv of bridge_stSrc_mmMaster is

  constant ADDR_BASE : std_logic_vector(NBITS_ADDR-1 downto 0) := x"38000000";
  signal fifoDataIn : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoDataOut : std_logic_vector(NBITS_DATA+1 downto 0);
  signal fifoFull, fifoEmpty : std_logic := '0';
  signal fifoWr, fifoRd : std_logic := '0';
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE;
  signal s_masterwrite : std_logic := '0';
  signal s_master_writedata : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');

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
  
begin  -- architecture bhv

  	dcfifo_component : dcfifo
	GENERIC MAP (
		intended_device_family => "Cyclone V",
		lpm_numwords => 1024,
		lpm_showahead => "ON",
		lpm_type => "dcfifo",
		lpm_width => NBITS_DATA+2,
		lpm_widthu => 10,
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
		wrfull => fifoFull
	);
        

        waitreq_proc: process (clk_mem, rst_n) is
        begin  -- process waitreq_proc
          if rst_n = '0' then           -- asynchronous reset (active low)
             s_address <= (others => '0');
          elsif clk_mem'event and clk_mem = '1' then  -- rising clock edge
            -- ADDR UPDATE
             if s_masterwrite = '1' and master_waitrequest = '0' then
              if fifoDataOut(NBITS_DATA+1) = '1' then --endofpacket                
                s_address <= ADDR_BASE;                
              else
                s_address <= std_logic_vector(unsigned(s_address) + 1);                
              end if;
            else
              s_address <= s_address;
            end if; 
            
          end if;
        end process waitreq_proc;
        
        fifoDataIn <= st_endofpacket & st_startofpacket & st_datain;
        fifoWr <= st_datavalid and (not fifoFull);
        fifoRd <= (not master_waitrequest) and (s_masterwrite);        
        st_ready <= not fifoFull;
        
        s_masterwrite <= not fifoEmpty;
        
        master_write <= s_masterwrite;
        master_address <= s_address;
        master_writedata <= fifoDataOut(NBITS_DATA-1 downto 0);

       
        --master_burstcount <= std_logic_vector(to_unsigned(BURST, NBITS_BURST));
        --master_byteenable <= (others => '1');


end architecture bhv;
