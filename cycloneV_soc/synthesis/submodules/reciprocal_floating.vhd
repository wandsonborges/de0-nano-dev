-------------------------------------------------------------------------------
-- Title      : reciprocal_floating
-- Project    : 
-------------------------------------------------------------------------------
-- File       : reciprocal_floating.vhd
-- Author     :   <mdrumond-ivision@hailstorm-arch>
-- Company    : 
-- Created    : 2014-08-08
-- Last update: 2014-08-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calcula o inverso multiplicativo da mantissa de um numero.
-- A entrada é a mantissa, e dever ser um numero de .5 a 1.0 (o bit mais
-- significativo deve ser 1) . A saida será o inverso multiplicativo desse
-- numero (reciprocal).
-- Esse bloco utiliza a aproximacao de newton-raphson. Essa aproximacao é iterativa
-- e o reciproco de um numero de 32 bits pode ser calculado em tres iteracoes
-- Para uma entrada m, a primeira aproximacao é feita:
-- x_init = (48/17) - (32/17)*m
-- As iteracoes sao:
-- prox_x = x + x*(1 - x*m)
-- A entrada desse bloco é a mantissa no formato 0.N - valor de 0.5 a 1.0
-- (excluso 1.0)
-- A saida é do formato 1.(N-1) - valor de 1.0 a 2.0 - excluso 2.0
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-08-08  1.0      mdrumond-ivision        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
entity reciprocal_floating is
  
  generic (
    LARGURA_MANTISSA : integer := 8);

  port (
    clk, rst_n       : in  std_logic;
    valid_in         : in  std_logic;
    mantissa_in      : in  std_logic_vector(LARGURA_MANTISSA-1 downto 0);
    valid_out        : out std_logic;
    rec_mantissa_out : out std_logic_vector(LARGURA_MANTISSA-1 downto 0));

end entity reciprocal_floating;

architecture fpga of reciprocal_floating is

  
  constant LARGURA_MULT_IN  : integer := 18;
  constant LARGURA_MULT_OUT : integer := 36;

  constant LARGURA_FRAC : integer := LARGURA_MULT_IN-2;
  constant LARGURA_INT  : integer := 1;

  -- purpose: Converte a mantissa para um multiplicando
  function mantissa_to_mult (
    mantissa : std_logic_vector)
    return signed is
    variable mantissa_shift : unsigned(LARGURA_MULT_IN-2 downto 0);
  begin  -- function mantissa_to_mult
    mantissa_shift := (others => '0');
    -- coloca a mantissa num registrador do tamanho de mult_in com o bit mais
    -- significativo (sinal) igual a 0 e os bits mais baixos iguais a 0.
    -- Corrige tambem o formato da mantissa de 0.N para 1.(N-1)
    mantissa_shift(LARGURA_MULT_IN-3 downto LARGURA_MULT_IN-3-LARGURA_MANTISSA+1)
      := unsigned(mantissa);
    
    return signed('0' & mantissa_shift);
  end function mantissa_to_mult;

  function mult_to_mantissa (
    mult : signed(LARGURA_MULT_IN-1 downto 0))
    return std_logic_vector is
    variable mantissa_aux : std_logic_vector(LARGURA_MANTISSA-1 downto 0);
  begin  -- function mult_to_mantissa
    mantissa_aux
      := std_logic_vector(mult(LARGURA_MULT_IN-2 downto
                               LARGURA_MULT_IN-2-LARGURA_MANTISSA+1));
    return mantissa_aux;
  end function mult_to_mantissa;

  function trunca_mac (
    mac_in : signed)
    return signed is
    variable sinal        : std_logic;
    variable int_bit      : std_logic;
    variable frac_bits    : std_logic_vector(LARGURA_MULT_IN-3 downto 0);
    variable mac_truncado : std_logic_vector(LARGURA_MULT_IN-1 downto 0);
  begin
    sinal   := mac_in(LARGURA_MULT_OUT-1);
    int_bit := mac_in(LARGURA_MULT_OUT-4);
    frac_bits := std_logic_vector(mac_in(LARGURA_MULT_OUT-5 downto
                                         LARGURA_MULT_OUT-5 - frac_bits'length + 1));
    mac_truncado := sinal & int_bit & frac_bits;
    return signed(mac_truncado);
  end function trunca_mac;

  -- purpose: Calcula a primeira aproximacao do algoritmo
  function get_aprox_inicial (
    mantissa : signed)
    return signed is
    variable aprox_aux      : signed(LARGURA_MULT_IN-1 downto 0);
    variable const1         : signed(LARGURA_MULT_IN-1 downto 0);
    variable const2         : signed(LARGURA_MULT_IN-1 downto 0);
    variable mult1          : signed(LARGURA_MULT_OUT-1 downto 0);
    variable mult1_truncado : signed(LARGURA_MULT_IN-1 downto 0);
  begin  -- function get_aprox_inicial
    -- saida da multiplicacao tem 2 bits de sinal
    -- esse numero esta no formato 1.1.16
    const1 := to_signed(integer(real(24.0/17.0)*(2.0**(LARGURA_FRAC))),
                        LARGURA_MULT_IN);

    -- garante o bit de sinal    
    -- esse numero esta no formato 1.1.16
    const2 := to_signed(integer(real(16.0/17.0)*(2.0**(LARGURA_FRAC))),
                        LARGURA_MULT_IN);

    -- saida dessa multiplicacao e (1.1.16 X 1.1.16) = 2.2.32
    mult1          := const2*mantissa;
    -- truncado para 1.1.16
    mult1_truncado := trunca_mac(mult1);
    -- resultado eh 1.1.16 - esta dividido por 2
    aprox_aux := const1 - mult1_truncado;
    -- corrige shiftando para a esquerda, e mantendo o sinal
    aprox_aux(LARGURA_MULT_IN-2 downto 1) := aprox_aux(LARGURA_MULT_IN-3 downto 0);
    aprox_aux(0) := '0';
    return aprox_aux;
  end function get_aprox_inicial;

  -- purpose: Realiza o primeiro mac do algoritmo de newton-raphson
  function nr_it_mac1 (
    ultima_aprox    : signed;
    mantissa_inicio : signed)
    return signed is
    variable const1        : signed(LARGURA_MULT_IN-1 downto 0);
    variable mult_out      : signed(LARGURA_MULT_OUT-1 downto 0);
    variable mult_out_truncado : signed(LARGURA_MULT_IN-1 downto 0);
    variable mac_out       : signed(LARGURA_MULT_IN-1 downto 0);
  begin  -- function nr_it_mac1
    -- saida da multiplicacao tem 2 bits de sinal
    const1            := to_signed(integer(1*2**LARGURA_FRAC), LARGURA_MULT_IN);
    mult_out          := ultima_aprox*mantissa_inicio;
    mult_out_truncado := trunca_mac(mult_out);
    mac_out           := const1 - mult_out_truncado;
    return mac_out;
  end function nr_it_mac1;

  -- purpose: Realiza o primeiro mac do algoritmo de newton-raphson
  function nr_it_mac2 (
    ultima_aprox : signed;
    mac1_out     : signed)
    return signed is
    variable mult_out          : signed(LARGURA_MULT_OUT-1 downto 0);
    variable mult_out_truncado : signed(LARGURA_MULT_IN-1 downto 0);
    variable mac_out           : signed(LARGURA_MULT_IN-1 downto 0);
  begin  -- function nr_it_mac2
    mult_out          := ultima_aprox*mac1_out;
    mult_out_truncado := trunca_mac(mult_out);
    mac_out           := mult_out_truncado + ultima_aprox;
    return mac_out;
  end function nr_it_mac2;

  type flop_in_t is record
    valid         : std_logic;
    mantissa_mult : signed(LARGURA_MULT_IN-1 downto 0);
  end record flop_in_t;
  constant DEF_FLOP_IN : flop_in_t := (
    valid         => '0',
    mantissa_mult => (others => '0'));
  signal flop_in : flop_in_t := DEF_FLOP_IN;

  type flop_primeira_aprox_t is record
    valid          : std_logic;
    mantissa_in    : signed(LARGURA_MULT_IN-1 downto 0);
    primeira_aprox : signed(LARGURA_MULT_IN-1 downto 0);
  end record flop_primeira_aprox_t;
  constant DEF_FLOP_PRIEMIRA_APROX : flop_primeira_aprox_t := (
    valid          => '0',
    mantissa_in    => (others => '0'),
    primeira_aprox => (others => '0'));
  signal flop_primeira_aprox : flop_primeira_aprox_t := DEF_FLOP_PRIEMIRA_APROX;

  type nr_it_mac1_t is record
    valid        : std_logic;
    saida_mac    : signed(LARGURA_MULT_IN-1 downto 0);
    ultima_aprox : signed(LARGURA_MULT_IN-1 downto 0);
    mantissa_in  : signed(LARGURA_MULT_IN-1 downto 0);
  end record nr_it_mac1_t;
  constant DEF_NR_IT_MAC1 : nr_it_mac1_t := (
    valid        => '0',
    saida_mac    => (others => '0'),
    ultima_aprox => (others => '0'),
    mantissa_in  => (others => '0'));

  type nr_it_mac2_t is record
    valid        : std_logic;
    ultima_aprox : signed(LARGURA_MULT_IN-1 downto 0);
    mantissa_in  : signed(LARGURA_MULT_IN-1 downto 0);
  end record nr_it_mac2_t;
  constant DEF_NR_IT_MAC2 : nr_it_mac2_t := (
    valid        => '0',
    ultima_aprox => (others => '0'),
    mantissa_in  => (others => '0'));

  type nr_it_t is record
    mac1 : nr_it_mac1_t;
    mac2 : nr_it_mac2_t;
  end record nr_it_t;
  constant DEF_NR_IT : nr_it_t := (
    mac1 => DEF_NR_IT_MAC1,
    mac2 => DEF_NR_IT_MAC2);

  constant NUM_ITERACOES : integer := 3;
  type nr_array_it_t is array (0 to NUM_ITERACOES-1) of nr_it_t;
  signal nr_array_it : nr_array_it_t := (
    others => DEF_NR_IT);


begin  -- architecture fpga

  assert LARGURA_MANTISSA <= LARGURA_MULT_IN-2 report "A mantissa é maior que o multiplicando do DSP. Durante o truncamento, os bits extras serao perdidos" severity failure;

  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_in             <= DEF_FLOP_IN;
      flop_primeira_aprox <= DEF_FLOP_PRIEMIRA_APROX;
      nr_array_it         <= (others => DEF_NR_IT);
    elsif clk'event and clk = '1' then  -- rising clock edge
      flop_in.valid <= valid_in;
      if '1' = valid_in then
        flop_in.mantissa_mult <= mantissa_to_mult(mantissa_in);
      end if;

      flop_primeira_aprox.valid <= flop_in.valid;
      if '1' = flop_in.valid then
        flop_primeira_aprox.mantissa_in <= flop_in.mantissa_mult;
        flop_primeira_aprox.primeira_aprox
          <= get_aprox_inicial(flop_in.mantissa_mult);
      end if;


      nr_array_it(0).mac1.valid <= flop_primeira_aprox.valid;
      if '1' = flop_primeira_aprox.valid then
        nr_array_it(0).mac1.mantissa_in  <= flop_primeira_aprox.mantissa_in;
        nr_array_it(0).mac1.ultima_aprox <= flop_primeira_aprox.primeira_aprox;
        nr_array_it(0).mac1.saida_mac
          <= nr_it_mac1(flop_primeira_aprox.primeira_aprox,
                        flop_primeira_aprox.mantissa_in);

      end if;

      nr_array_it(0).mac2.valid <= nr_array_it(0).mac1.valid;
      if '1' = nr_array_it(0).mac1.valid then
        nr_array_it(0).mac2.mantissa_in <= nr_array_it(0).mac1.mantissa_in;
        nr_array_it(0).mac2.ultima_aprox
          <= nr_it_mac2(nr_array_it(0).mac1.ultima_aprox,
                        nr_array_it(0).mac1.saida_mac);

      end if;

      for i in 1 to NUM_ITERACOES-1 loop
        nr_array_it(i).mac1.valid <= nr_array_it(i-1).mac2.valid;
        if '1' = nr_array_it(i-1).mac2.valid then
          nr_array_it(i).mac1.mantissa_in  <= nr_array_it(i-1).mac2.mantissa_in;
          nr_array_it(i).mac1.ultima_aprox <= nr_array_it(i-1).mac2.ultima_aprox;
          nr_array_it(i).mac1.saida_mac
            <= nr_it_mac1(nr_array_it(i-1).mac2.ultima_aprox,
                          nr_array_it(i-1).mac2.mantissa_in);
        end if;

        nr_array_it(i).mac2.valid <= nr_array_it(i).mac1.valid;
        if '1' = nr_array_it(i).mac1.valid then
          nr_array_it(i).mac2.mantissa_in <= nr_array_it(i).mac1.mantissa_in;
          nr_array_it(i).mac2.ultima_aprox
            <= nr_it_mac2(nr_array_it(i).mac1.ultima_aprox,
                          nr_array_it(i).mac1.saida_mac);
        end if;

      end loop;  -- i

    end if;
  end process clk_proc;

  valid_out <= nr_array_it(NUM_ITERACOES-1).mac2.valid;
  rec_mantissa_out
    <= mult_to_mantissa(nr_array_it(NUM_ITERACOES-1).mac2.ultima_aprox);
end architecture fpga;
