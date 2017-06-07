-------------------------------------------------------------------------------
-- Title      : Homografia de Imagem
-- Project    : 
-------------------------------------------------------------------------------
-- File       : homography.vhd
-- Author     :   <rodrigo@snowden>
-- Company    : 
-- Created    : 2015-05-20
-- Last update: 2017-06-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Realiza a homografia de imagens no Video_DMA
-------------------------------------------------------------------------------
-- Copyright (c) 2015 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-05-20  1.0      rodrigo	Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
library lpm;
use lpm.all;

entity homography_core  is
  
  generic (
    WIDTH : integer := 320;
    HEIGHT : integer := 240;
    CICLOS_LATENCIA : integer := 8;
    WW : integer := 8;
    HW : integer := 7;
    n_bits_int  : integer := 12;
    n_bits_frac : integer := 20);

  port (
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    inc_addr    : in  std_logic;
    sw          : in  std_logic_vector(17 downto 0);
    x_in        : in  std_logic_vector(WW-1 downto 0);
    y_in        : in  std_logic_vector(HW-1 downto 0);
    last_data   : out std_logic;
    x_out       : out std_logic_vector(WW-1 downto 0);
    y_out       : out std_logic_vector(HW-1 downto 0));

end entity homography_core;

architecture bhv of homography_core is
  constant MEW : integer := n_bits_int + n_bits_frac;
  subtype ponto_matriz_homog_t is std_logic_vector(MEW-1 downto 0);
  type linha_matriz_homog_t is array (0 to 2) of ponto_matriz_homog_t;
  type matriz_homog_t is array (0 to 2) of linha_matriz_homog_t;


  signal x_calc, y_calc, div_calc : signed(MEW-1 downto 0) := (others => '0');
  signal x_out_full, y_out_full : std_logic_vector(x_calc'length-1 downto 0) := (others => '0');
  signal x_out_div, y_out_div : std_logic_vector(x_calc'length-1 downto 0) := (others => '0');
  signal x_accu1, x_accu2, x_accu3, x_offset, div_offset : signed(MEW-1 downto 0) := (others => '0');
  signal y_accu1, y_accu2, y_accu3, y_offset : signed(MEW-1 downto 0) := (others => '0');
  signal clear_delay : std_logic;
  signal x_out_read : std_logic_vector(x_out'length-1 downto 0);
  signal y_out_read : std_logic_vector(y_out'length-1 downto 0);
  signal usa_div : std_logic := '0';
  signal soft_matrix : std_logic_vector(287 downto 0) := (others => '0');

  
-- 90 graus
  constant MATRIZ_HOMOG_1 : matriz_homog_t :=
    ((std_logic_vector(to_signed(0, MEW)),
 std_logic_vector(to_signed(-1048576, MEW)),
 std_logic_vector(to_signed(293601280, MEW))),
  (std_logic_vector(to_signed(1048576, MEW)),
  std_logic_vector(to_signed(0, MEW)),
  std_logic_vector(to_signed(-41943039, MEW))),
  (std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(1048576, MEW))) );

 -- 45 graus
  constant MATRIZ_HOMOG_0 : matriz_homog_t := 
((std_logic_vector(to_signed(741455, MEW)),
 std_logic_vector(to_signed(-741455, MEW)),
 std_logic_vector(to_signed(138113951, MEW))),
  (std_logic_vector(to_signed(741455, MEW)),
  std_logic_vector(to_signed(741455, MEW)),
  std_logic_vector(to_signed(-81778336, MEW))),
  (std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(1048576, MEW))) );
  
constant MATRIZ_HOMOG_ID : matriz_homog_t := 
((std_logic_vector(to_signed(1048576, MEW)),
 std_logic_vector(to_signed(0, MEW)),
 std_logic_vector(to_signed(0, MEW))),
  (std_logic_vector(to_signed(0, MEW)),
  std_logic_vector(to_signed(1048576, MEW)),
  std_logic_vector(to_signed(0, MEW))),
  (std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(0, MEW)),
   std_logic_vector(to_signed(1048576, MEW))) );

  constant MATRIZ_HOMOG_CAM : matriz_homog_t := 
((std_logic_vector(to_signed(-174503, MEW)),
 std_logic_vector(to_signed(77536, MEW)),
 std_logic_vector(to_signed(-22445259, MEW))),
  (std_logic_vector(to_signed(2567, MEW)),
  std_logic_vector(to_signed(28640, MEW)),
  std_logic_vector(to_signed(-68630697, MEW))),
  (std_logic_vector(to_signed(7, MEW)),
   std_logic_vector(to_signed(636, MEW)),
   std_logic_vector(to_signed(-431639, MEW))) );
  

  
  
  signal matriz_homog: matriz_homog_t := MATRIZ_HOMOG_0;
  signal matriz_homog_soft : matriz_homog_t := MATRIZ_HOMOG_0;
  
  

begin  -- architecture bhv

  x_out_full <= std_logic_vector(x_calc srl n_bits_frac);
  x_out <= x_out_read(WW-1 downto 0) when signed(x_out_read) < WIDTH and signed(x_out_read) >= 0 and signed(y_out_read) < HEIGHT and signed(y_out_read) >= 0 else (others => '0');

  y_out_full <= std_logic_vector(y_calc srl n_bits_frac);
  y_out <= y_out_read(HW-1 downto 0)  when signed(x_out_read) < WIDTH and signed(x_out_read) >= 0 and signed(y_out_read) < HEIGHT and signed(y_out_read) >= 0 else (others => '0');


  x_out_read <= x_out_full(WW-1 downto 0) when usa_div = '0' else x_out_div(WW-1 downto 0);
  y_out_read <= y_out_full(HW-1 downto 0) when usa_div = '0' else y_out_div(HW-1 downto 0);

  x_offset <= signed(MATRIZ_HOMOG(0)(2));
  y_offset <= signed(MATRIZ_HOMOG(1)(2));
  div_offset <= signed(MATRIZ_HOMOG(2)(2));
  accum_control_process: process (clk, rst_n) is
  begin  -- process accum_control_process
    if rst_n = '0' then                 -- asynchronous reset (active low)
      x_accu1 <= (others => '0'); 
      x_accu2 <= (others => '0'); 
      x_accu3 <= (others => '0'); 
      y_accu1 <= (others => '0'); 
      y_accu2 <= (others => '0'); 
      y_accu3 <= (others => '0');
      matriz_homog <= MATRIZ_HOMOG_ID;
    elsif clk'event and clk = '1' then  -- rising clock edge
      if inc_addr = '1' then
        if ((unsigned(x_in) = (WIDTH - 1)) and (unsigned(y_in) = (HEIGHT - 1))) then
          x_accu1 <= (others => '0'); 
          x_accu2 <= (others => '0');
          x_accu3 <= (others => '0');
          y_accu1 <= (others => '0');
          y_accu2 <= (others => '0');
          y_accu3 <= (others => '0');
          last_data <= '1';
          if unsigned(sw) = 1 then
            matriz_homog <= MATRIZ_HOMOG_1;
            usa_div <= '0';
          elsif unsigned(sw) = 2 then
            matriz_homog <= MATRIZ_HOMOG_0;
            usa_div <= '0';
          elsif unsigned(sw) = 3 then
            matriz_homog <= MATRIZ_HOMOG_CAM;
            usa_div <= '1';
          elsif unsigned(sw) = 4 then
            matriz_homog <= matriz_homog_soft;
            usa_div <= '1';
          else
            matriz_homog <= MATRIZ_HOMOG_ID;
            usa_div <= '0';
          end if;
        elsif (unsigned(x_in) = (WIDTH - 1)) then
          last_data <= '0';
          x_accu1 <= (others => '0'); 
          x_accu2 <= (others => '0');
          x_accu3 <= (others => '0');
          y_accu1 <= y_accu1 + signed(MATRIZ_HOMOG(0)(1));
          y_accu2 <= y_accu2 + signed(MATRIZ_HOMOG(1)(1));
          y_accu3 <= y_accu3 + signed(MATRIZ_HOMOG(2)(1));
        else
          last_data <= '0';
          x_accu1 <= x_accu1 + signed(MATRIZ_HOMOG(0)(0));
          x_accu2 <= x_accu2 + signed(MATRIZ_HOMOG(1)(0));
          x_accu3 <= x_accu3 + signed(MATRIZ_HOMOG(2)(0));
        end if;
      end if;      

      
    end if;
  end process accum_control_process;

      x_calc <= x_accu1 + y_accu1 + x_offset; 
      y_calc <= x_accu2 + y_accu2 + y_offset;
      div_calc <= x_accu3 + y_accu3 + div_offset;


--  last_data <= '1' when ((unsigned(x_in) = WIDTH-1) and (unsigned(y_in) = HEIGHT-1)) else '0';
  
    divisor1 : lpm.lpm_components.lpm_divide
    generic map(
      lpm_widthd          => MEW,
      lpm_pipeline        => CICLOS_LATENCIA,
      lpm_hint            => "MAXIMIZE_SPEED=7, LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_drepresentation => "SIGNED",
      lpm_widthn          => MEW)
    port map(
      clock    => clk,
      --remain   : out std_logic_vector (lpm_widthd-1 downto 0);
      clken    => '1',
      numer    => std_logic_vector(x_calc),
      denom    => std_logic_vector(div_calc),
      quotient => x_out_div
      );

divisor2 : lpm.lpm_components.lpm_divide
    generic map(
      lpm_widthd          => MEW,
      lpm_pipeline        => CICLOS_LATENCIA,
      lpm_hint            => "MAXIMIZE_SPEED=7, LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_drepresentation => "SIGNED",
      lpm_widthn          => MEW)
    port map(
      clock    => clk,
      clken    => '1',
      numer    => std_logic_vector(y_calc),
      denom    => std_logic_vector(div_calc),
      quotient => y_out_div
      );


  -- megafunc_probe_1: entity work.megafunc_probe
  --   port map (
  --     probe      => (others => '0'),
  --     source_clk => clk,
  --     source_ena => '1',
  --     source     => soft_matrix);
  

 matriz_homog_soft(0)(0) <= soft_matrix(287 downto 256);
 matriz_homog_soft(0)(1) <= soft_matrix(255 downto 224);
 matriz_homog_soft(0)(2) <= soft_matrix(223 downto 192);

 matriz_homog_soft(1)(0) <= soft_matrix(191 downto 160);
 matriz_homog_soft(1)(1) <= soft_matrix(159 downto 128);
 matriz_homog_soft(1)(2) <= soft_matrix(127 downto 96);

 matriz_homog_soft(2)(0) <= soft_matrix(95 downto 64);
 matriz_homog_soft(2)(1) <= soft_matrix(63 downto 32);
 matriz_homog_soft(2)(2) <= soft_matrix(31 downto 0); 
  
  


end architecture bhv;
