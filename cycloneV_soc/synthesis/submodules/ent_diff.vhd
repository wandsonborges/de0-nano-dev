-------------------------------------------------------------------------------
-- Title      : ent_diff
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ent_diff.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-12
-- Last update: 2014-08-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calcula a diferenca entre os angulos utilizando as derivadas
--              das duas imagens
--              O calculo e feito da seguinte maneira:
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-12  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

--library lpm;

--use lpm.all;
--use lpm.lpm_components.all;


entity ent_diff is
  generic (
    LARGURA_PIXEL : integer := 8;
    LARGURA_SAIDA : integer := 4);
  --NORMA_THRESHOLD : integer := 40);
  port (
    clk, rst_n                         : in  std_logic;
    img1_dx, img2_dx, img1_dy, img2_dy : in  std_logic_vector(LARGURA_PIXEL+3-1 downto 0);
    valido_in                          : in  std_logic;
    diff_out                           : out std_logic_vector(LARGURA_SAIDA-1 downto 0);
    ang_count                          : out std_logic;
    norma_threshold                    : in  std_logic_vector(LARGURA_PIXEL+2-1 downto 0);
    valido_out                         : out std_logic);

end entity ent_diff;

architecture fpga of ent_diff is
  -- Ao tirar o modulo das entradas nos descartamos um bit.
  -- So utilizamos os modulos das entradas pois nos queremos um angulo no
  -- primeiro quadrante
  constant LARGURA_ENTRADA     : integer := LARGURA_PIXEL+3;
  constant LARGURA_ENTRADA_MOD : integer := LARGURA_PIXEL+2;  -- 10
  constant DIV_DELAY           : integer := 8;

  constant LARGURA_MULT1_OUT      : integer := 2*LARGURA_ENTRADA_MOD;  -- 20
  constant LARGURA_SUM1_OUT       : integer := LARGURA_MULT1_OUT + 1;
  constant LARGURA_MULT2_IN       : integer := 18;
  constant LARGURA_SHIFT_SUM1_OUT : integer := LARGURA_SUM1_OUT- LARGURA_MULT2_IN;
  constant LARGURA_MULT2_OUT      : integer := 36;

  constant LARGURA_EXPOENTE_MULT : integer := 6;
  constant LARGURA_MANTISSA_MULT : integer := 16;

  constant LARGURA_DIV_NUM       : integer := 24;
  constant LARGURA_SHIFT_DIV_NUM : integer := LARGURA_MULT2_OUT - LARGURA_DIV_NUM;
  constant LARGURA_DIV_DEN       : integer := LARGURA_DIV_NUM - LARGURA_SAIDA;
  constant LARGURA_SHIFT_DIV_DEN : integer := LARGURA_MULT2_OUT - LARGURA_DIV_DEN;

  subtype ent_diff_t is unsigned(LARGURA_ENTRADA_MOD-1 downto 0);

  type flop_init_t is record
    valido                             : std_logic;
    img1_dx, img2_dx, img1_dy, img2_dy : ent_diff_t;
  end record flop_init_t;
  
  constant DEF_FLOP_INIT : flop_init_t := (
    img1_dx => (others => '0'),
    img2_dx => (others => '0'),
    img1_dy => (others => '0'),
    img2_dy => (others => '0'),
    valido  => '0');
  signal flop_init : flop_init_t := DEF_FLOP_INIT;

  subtype mult1_out_t is unsigned(LARGURA_MULT1_OUT-1 downto 0);
  subtype sum1_out_t is unsigned(LARGURA_MULT2_IN-1 downto 0);
  subtype div_num_t is std_logic_vector(LARGURA_DIV_NUM-1 downto 0);
  subtype div_den_t is std_logic_vector(LARGURA_DIV_DEN-1 downto 0);

  type flop_mult1_t is record
    valido                               : std_logic;
    x1_2, x2_2, y1_2, y2_2, x1_x2, y1_y2 : mult1_out_t;
  end record flop_mult1_t;
  constant DEF_FLOP_MULT1 : flop_mult1_t := (
    valido => '0',
    x1_2   => (others => '0'),
    x2_2   => (others => '0'),
    y1_2   => (others => '0'),
    y2_2   => (others => '0'),
    x1_x2  => (others => '0'),
    y1_y2  => (others => '0'));
  signal flop_mult1 : flop_mult1_t := DEF_FLOP_MULT1;

  type flop_sum1_t is record
    valido                            : std_logic;
    norma1_2, norma2_2, diff_num_sqrt : sum1_out_t;
    threshold_corrigido               : sum1_out_t;
  end record flop_sum1_t;
  constant DEF_FLOP_SUM1 : flop_sum1_t := (
    valido              => '0',
    threshold_corrigido => (others => '0'),
    norma1_2            => (others => '0'),
    norma2_2            => (others => '0'),
    diff_num_sqrt       => (others => '0'));
  signal flop_sum1 : flop_sum1_t := DEF_FLOP_SUM1;

  type flop_mult2_t is record
    valido    : std_logic;
    ang_count : std_logic;
    diff_den  : std_logic_vector(LARGURA_MULT2_OUT-1 downto 0);
    diff_num  : std_logic_vector(LARGURA_MULT2_OUT-1 downto 0);
  end record flop_mult2_t;
  constant DEF_FLOP_MULT2 : flop_mult2_t := (
    valido    => '0',
    ang_count => '0',
    diff_den  => (others => '1'),
    diff_num  => (others => '1'));
  signal flop_mult2 : flop_mult2_t := DEF_FLOP_MULT2;

  type flop_delay_small_t is record
    valido    : std_logic;
    ang_count : std_logic;
  end record flop_delay_small_t;
  constant DEF_FLOP_DELAY_SMALL : flop_delay_small_t
    := (valido => '0', ang_count => '0');

  type flop_delay_big_t is record
    valido    : std_logic;
    ang_count : std_logic;
    expoente  : std_logic_vector(LARGURA_EXPOENTE_MULT downto 0);
    mantissa  : std_logic_vector(LARGURA_MANTISSA_MULT-1 downto 0);
  end record flop_delay_big_t;
  
  constant DEF_FLOP_DELAY_BIG : flop_delay_big_t := (
    valido    => '0',
    ang_count => '0',
    expoente  => (others => '0'),
    mantissa  => (others => '0'));

  type array_delay_t is array (0 to DIV_DELAY-1) of flop_delay_big_t;
  constant DEF_ARRAY_DELAY : array_delay_t := (others => DEF_FLOP_DELAY_BIG);
  signal array_delay       : array_delay_t := DEF_ARRAY_DELAY;

  signal delay_to_float, delay_to_fixed : flop_delay_small_t := DEF_FLOP_DELAY_SMALL;
  signal flop_mult_rec                  : flop_delay_big_t   := DEF_FLOP_DELAY_BIG;

  signal mantissa_den, mantissa_num,
    rec_mantissa_den : std_logic_vector(LARGURA_MANTISSA_MULT-1 downto 0);
  signal expoente_den, expoente_num : std_logic_vector(LARGURA_EXPOENTE_MULT-1 downto 0);

  signal ang_diff_fixed : std_logic_vector(LARGURA_SAIDA-1 downto 0);

  -- purpose: calcula o valor absoluto da saida do sobel
  function mod_derivativo (
    signal derivativo : std_logic_vector(LARGURA_ENTRADA-1 downto 0))
    return ent_diff_t is
    variable saida_aux : ent_diff_t;
  begin  -- function mod_derivativo
    if signed(derivativo) < 0 then
      saida_aux := resize(unsigned(-signed(derivativo)), LARGURA_ENTRADA_MOD);
    else
      saida_aux := resize(unsigned(derivativo), LARGURA_ENTRADA_MOD);
    end if;

    return saida_aux;
  end function mod_derivativo;

  --function get_threshould_corrigido (
  --  constant THRESHOLD : integer)
  --  return integer is
  --begin
  --  return (THRESHOLD**2)/(2** LARGURA_SHIFT_SUM1_OUT);
  --end function get_threshould_corrigido;
  --constant THRESHOLD_CORRIGIDO : integer := get_threshould_corrigido(NORMA_THRESHOLD);


  -- purpose: Soma dois unsigned e trunca o resultado para o tamanho da entrada
  -- do multiplicador
  function soma_trunca (
    signal parcela1, parcela2 : mult1_out_t)
    return sum1_out_t is
    variable parcela1_aux, parcela2_aux : unsigned(LARGURA_SUM1_OUT-1 downto 0);
    variable soma_aux                   : unsigned(LARGURA_SUM1_OUT-1 downto 0);
  begin  -- function soma_trunca
    parcela1_aux := resize(parcela1, LARGURA_SUM1_OUT);
    parcela2_aux := resize(parcela2, LARGURA_SUM1_OUT);
    soma_aux     := parcela1_aux + parcela2_aux;

    return resize(shift_right(soma_aux, LARGURA_SHIFT_SUM1_OUT), LARGURA_MULT2_IN);
  end function soma_trunca;

  -- purpose: Soma dois unsigned e trunca o resultado
  function mult_norma (
    signal valor : std_logic_vector(LARGURA_ENTRADA_MOD-1 downto 0))
    return sum1_out_t is
    variable mult_aux : unsigned(LARGURA_SUM1_OUT-1 downto 0);
  begin  -- function mult_norma
    mult_aux := unsigned('0' & (unsigned(valor)*unsigned(valor)));

    return resize(shift_right(mult_aux, LARGURA_SHIFT_SUM1_OUT), LARGURA_MULT2_IN);
  end function mult_norma;

  function mult_trunca (
    fator1, fator2 : unsigned)
    return unsigned is
    variable mult_out : unsigned(LARGURA_MULT2_OUT-1 downto 0);
    
  begin
    mult_out := fator1*fator2;
    return mult_out;
  end function mult_trunca;

  function mult_rec (
    rec_mantissa, num_mantissa : std_logic_vector(LARGURA_MANTISSA_MULT-1 downto 0))
    return std_logic_vector is
    variable mult_out          : unsigned(2*LARGURA_MANTISSA_MULT-1 downto 0);
    variable mult_out_truncado : unsigned(LARGURA_MANTISSA_MULT-1 downto 0);
  begin
    -- mult out sera 1.(2*largura_mantissa_mult-1)
    -- trunca para 1.(largura_mantissa-1)
    mult_out := unsigned(rec_mantissa)*unsigned(num_mantissa);
    mult_out_truncado := mult_out(mult_out'high downto
                                  mult_out'high-LARGURA_MANTISSA_MULT+1);
    return std_logic_vector(mult_out_truncado);
    
  end function mult_rec;

  signal norma_threshold_i : std_logic_vector(LARGURA_PIXEL+2-1 downto 0);
  
begin  -- architecture fpga

  norma_threshold_i <= norma_threshold;  -- default = 64


  -- purpose: Implementa o calculo da diferenca de angulo
  -- type   : sequential
  -- inputs : clk, rst_n, img1_norma, img2_norma, img1_ang, img2_ang, valido_in
  -- outputs: flop_out
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_init      <= DEF_FLOP_INIT;
      flop_mult1     <= DEF_FLOP_MULT1;
      flop_sum1      <= DEF_FLOP_SUM1;
      flop_mult2     <= DEF_FLOP_MULT2;
      delay_to_float <= DEF_FLOP_DELAY_SMALL;
      array_delay    <= DEF_ARRAY_DELAY;
      flop_mult_rec  <= DEF_FLOP_DELAY_BIG;
      delay_to_fixed <= DEF_FLOP_DELAY_SMALL;
    elsif clk'event and clk = '1' then  -- rising clock edge

      flop_init.valido <= valido_in;
      if valido_in = '1' then
        flop_init.img1_dx <= mod_derivativo(img1_dx);
        flop_init.img1_dy <= mod_derivativo(img1_dy);
        flop_init.img2_dx <= mod_derivativo(img2_dx);
        flop_init.img2_dy <= mod_derivativo(img2_dy);
      end if;
      flop_mult1.valido <= flop_init.valido;
      flop_mult1.x1_2   <= flop_init.img1_dx*flop_init.img1_dx;
      flop_mult1.y1_2   <= flop_init.img1_dy*flop_init.img1_dy;
      flop_mult1.x2_2   <= flop_init.img2_dx*flop_init.img2_dx;
      flop_mult1.y2_2   <= flop_init.img2_dy*flop_init.img2_dy;
      flop_mult1.x1_x2  <= flop_init.img1_dx*flop_init.img2_dx;
      flop_mult1.y1_y2  <= flop_init.img1_dy*flop_init.img2_dy;

      flop_sum1.valido              <= flop_mult1.valido;
      flop_sum1.norma1_2            <= soma_trunca(flop_mult1.x1_2, flop_mult1.y1_2);
      flop_sum1.norma2_2            <= soma_trunca(flop_mult1.x2_2, flop_mult1.y2_2);
      flop_sum1.diff_num_sqrt       <= soma_trunca(flop_mult1.x1_x2, flop_mult1.y1_y2);
      --flop_sum1.threshold_corrigido <= mult_norma(norma_threshold);
      flop_sum1.threshold_corrigido <= mult_norma(norma_threshold_i);

      flop_mult2.valido <= flop_sum1.valido;
      flop_mult2.diff_den <= std_logic_vector(mult_trunca(flop_sum1.norma1_2,
                                                          flop_sum1.norma2_2));
      flop_mult2.diff_num <= std_logic_vector(mult_trunca(flop_sum1.diff_num_sqrt,
                                                          flop_sum1.diff_num_sqrt));


      if (flop_sum1.norma1_2 > flop_sum1.threshold_corrigido) and
        (flop_sum1.norma2_2 > flop_sum1.threshold_corrigido) then
        flop_mult2.ang_count <= '1';
      else
        flop_mult2.ang_count <= '0';
      end if;

      -- delay para converter os algarismos para ponto flutuante
      delay_to_float.valido    <= flop_mult2.valido;
      delay_to_float.ang_count <= flop_mult2.ang_count;

      -- delay para a saida do reciproco
      array_delay(0).valido    <= delay_to_float.valido;
      array_delay(0).ang_count <= delay_to_float.ang_count;
      -- corrige o expoente: +1 para a divisao +4 para o endereco da bin
      array_delay(0).expoente <= std_logic_vector(signed('0' & expoente_num)-
                                                  signed('0' & expoente_den)+5);
      array_delay(0).mantissa <= mantissa_num;

      for i in 1 to DIV_DELAY-1 loop
        array_delay(i) <= array_delay(i-1);
      end loop;  -- i

      -- realiza a multiplicacao
      flop_mult_rec.valido    <= array_delay(DIV_DELAY-1).valido;
      flop_mult_rec.ang_count <= array_delay(DIV_DELAY-1).ang_count;
      flop_mult_rec.expoente  <= array_delay(DIV_DELAY-1).expoente;
      flop_mult_rec.mantissa <= mult_rec(rec_mantissa_den,
                                         array_delay(DIV_DELAY-1).mantissa);

      -- converte para fixed denovo para obter o ang count
      delay_to_fixed.valido    <= flop_mult_rec.valido;
      delay_to_fixed.ang_count <= flop_mult_rec.ang_count;

    end if;
  end process clk_proc;

  valido_out <= delay_to_fixed.valido;
  ang_count  <= delay_to_fixed.ang_count;
  diff_out   <= ang_diff_fixed;

  den_to_float : entity work.fixed_to_float
    generic map (
      LARGURA_MANTISSA => LARGURA_MANTISSA_MULT,
      LARGURA_EXPOENTE => LARGURA_EXPOENTE_MULT,
      LARGURA_FIXED    => LARGURA_MULT2_OUT)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      valid_in       => '1',
      fixed_in       => flop_mult2.diff_den,
      valid_out      => open,
      float_mantissa => mantissa_den,
      float_expoente => expoente_den);

  num_to_float : entity work.fixed_to_float
    generic map (
      LARGURA_MANTISSA => LARGURA_MANTISSA_MULT,
      LARGURA_EXPOENTE => LARGURA_EXPOENTE_MULT,
      LARGURA_FIXED    => LARGURA_MULT2_OUT)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      valid_in       => '1',
      fixed_in       => flop_mult2.diff_num,
      valid_out      => open,
      float_mantissa => mantissa_num,
      float_expoente => expoente_num);

  reciprocal_floating_1 : entity work.reciprocal_floating
    generic map (
      LARGURA_MANTISSA => LARGURA_MANTISSA_MULT)
    port map (
      clk              => clk,
      rst_n            => rst_n,
      valid_in         => '1',
      mantissa_in      => mantissa_den,
      valid_out        => open,
      rec_mantissa_out => rec_mantissa_den);

  float_to_fixed_1 : entity work.float_to_fixed
    generic map (
      LARGURA_MANTISSA   => LARGURA_MANTISSA_MULT,
      LARGURA_EXPOENTE   => LARGURA_EXPOENTE_MULT+1,
      LARGURA_FIXED_FRAC => 0,
      LARGURA_FIXED_INT  => LARGURA_SAIDA)
    port map (
      clk         => clk,
      rst_n       => rst_n,
      valid_in    => '1',
      mantissa_in => flop_mult_rec.mantissa,
      expoente_in => flop_mult_rec.expoente,
      valid_out   => open,
      fixed_out   => ang_diff_fixed);

  --LPM_DIVIDE_1 : lpm.lpm_components.lpm_divide
  --  generic map (
  --    lpm_drepresentation => "UNSIGNED",
  --    lpm_hint            => "MAXIMIZE_SPEED=7,LPM_REMAINDERPOSITIVE=TRUE",
  --    lpm_nrepresentation => "UNSIGNED",
  --    lpm_pipeline        => DIV_DELAY,
  --    lpm_type            => "LPM_DIVIDE",
  --    lpm_widthd          => LARGURA_DIV_DEN,
  --    lpm_widthn          => LARGURA_DIV_NUM
  --    )
  --  port map (
  --    clock    => clk,
  --    clken    => '1',
  --    denom    => flop_mult2.diff_den,
  --    numer    => flop_mult2.diff_num,
  --    remain   => open,
  --    quotient => div_quociente_out
  --    );


end architecture fpga;
