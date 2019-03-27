library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.all;
LIBRARY lpm;
USE lpm.all;

-- Retorna o valor medio do frame
entity mean_frame is  
  generic (
    NBITS_PXL  : integer := 16    
    );
  port (
    rst_n      : in  std_logic;
    clk        : in  std_logic;
    pxl_valid  : in  std_logic;
    frame_size : in std_logic_vector(31 downto 0);
    pxl_value  : in  std_logic_vector(NBITS_PXL-1 downto 0);
    mean_value : out std_logic_vector(NBITS_PXL-1 downto 0)
    );
end entity mean_frame;

architecture bhv of mean_frame is
  
  COMPONENT lpm_divide
    GENERIC (
      lpm_drepresentation : STRING;
      lpm_hint		  : STRING;
      lpm_nrepresentation : STRING;
      lpm_pipeline	  : NATURAL;
      lpm_type		  : STRING;
      lpm_widthd	  : NATURAL;
      lpm_widthn	  : NATURAL
      );
    PORT (
      clock	: IN  STD_LOGIC ;
      denom	: IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
      numer	: IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
      quotient	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
      remain	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
      );
  END COMPONENT;
  
  --
  signal pxl_acc     : unsigned(31 downto 0) := (others => '0');        
  signal pxl_counter : unsigned(31 downto 0) := (others => '0');       

  signal mean_reg  : STD_LOGIC_VECTOR(NBITS_PXL-1 downto 0);
  signal mean_reg_undiv  : STD_LOGIC_VECTOR(NBITS_PXL-1 downto 0);
  signal mean_calc : STD_LOGIC_VECTOR(31 downto 0);

  signal trig_fim       : STD_LOGIC_VECTOR(0 downto 0) := "0";
  signal trig_fim_flops : STD_LOGIC_VECTOR(0 downto 0) := "0";

  signal s_frame_size : STD_LOGIC_VECTOR(31 downto 0);

--
begin -- architecture bhv

  --
  acc_proc: process (clk, rst_n) is
  begin  -- process acc_proc
    if (rst_n = '0') then -- asynchronous reset (active low)
      pxl_counter <= (others => '0');
      pxl_acc     <= (others => '0');
      trig_fim    <= (others => '0');
      mean_reg_undiv <= (others => '0');
      
    elsif ((clk'event) and (clk = '1')) then -- rising clock edge
      if (pxl_counter = unsigned(s_frame_size)) then
        trig_fim    <= "1";
        pxl_acc     <= (others => '0');          
        pxl_counter <= (others => '0');
        s_frame_size <= frame_size;
        mean_reg_undiv <= std_logic_vector(pxl_acc(31 downto 24)); 
      elsif (pxl_valid = '1') then
        trig_fim    <= "0";
        pxl_acc     <= pxl_acc + unsigned(pxl_value);
        pxl_counter <= pxl_counter + 1;
        mean_reg_undiv <= mean_reg_undiv;
        s_frame_size <= s_frame_size;
      else
        trig_fim    <= "0";
        pxl_acc     <= pxl_acc;
        pxl_counter <= pxl_counter;
        mean_reg_undiv <= mean_reg_undiv;
        s_frame_size <= s_frame_size;

      end if;
    end if;
  end process acc_proc;    


  delay_regs_1: entity work.delay_regs
    generic map (
      cycles => 8-1,
      width  => 1
      )
    port map (
      clk    => clk,
      rst_n  => rst_n,
      en     => '1',
      input  => trig_fim,
      output => trig_fim_flops
      );

  trig_proc: process (clk, rst_n) is
  begin  -- process trig_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      mean_reg <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (trig_fim_flops(0) = '1') then
        mean_reg <= mean_calc(NBITS_PXL-1 downto 0);
      else
        mean_reg <= mean_reg;
      end if;      
    end if;
  end process trig_proc;
  

  divisor : LPM_DIVIDE
    GENERIC MAP (
      lpm_drepresentation => "UNSIGNED",
      lpm_hint            => "MAXIMIZE_SPEED=5,LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "UNSIGNED",
      lpm_pipeline        => 8,
      lpm_type            => "LPM_DIVIDE",
      lpm_widthd          => 32,
      lpm_widthn          => 32
      )
    PORT MAP (
      clock    => clk,
      denom    => s_frame_size,
      numer    => STD_LOGIC_VECTOR(pxl_acc),
      quotient => mean_calc,
      remain   => open
      );


  --mean_value <= mean_reg_undiv;
  mean_value <= mean_reg;
  
end architecture bhv;
