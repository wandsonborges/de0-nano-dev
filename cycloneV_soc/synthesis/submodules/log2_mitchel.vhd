-- TODO adicionar clk_en e testar
-------------------------------------------------------------------------------
-- Title      : log2_mitchel
-- Project    : 
-------------------------------------------------------------------------------
-- File       : log2_mitchel.vhd
-- Author     :   <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-10-09
-- Last update: 2014-08-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Impelementa o log2 de um numero em ponto fixo.
--              Utiliza o algoritmo de mitchel onde:
--              Um numero N pode ser expresso como: N = (2**k)*(1+f)
--              logo, log2(N) = log2(2**k) + log2(1+f)
--                    log2(N)~= k + f, aproximando log2(1+f) ~= f
--              Essa aproximacao se provou precisa o bastante.
--              Para encontrar k, basta se encontrar o 1 mais significativo
--              em N. A posicao desse 1 sera o valor de k.
--              f pode ser encontrado fazendo: f= (N>>k - 1)
--
--              No pipeline, k 'e encontrado no primeiro estagio
--              No segundo estagio, N>>k e calculado e no terceiro
--              (N>>k - 1)+k e calculado
--
--              Consideracao sobre largura dos dados
--              dado a largura de entrada: ei.ef e de saida: si.sf tem-se:
--              si >= log2(ei)
--              sf pode ser qualquer valor
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-10-09  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity log2_mitchel is
  
  generic (
    LARGURA_ENTRADA_INT  : integer := 8;
    PRECISAO_ENTRADA_LUT : integer := 9;
    LARGURA_SAIDA_INT    : integer := 8;
    LARGURA_SAIDA_FRAC   : integer := 8);

  port (
    clk, rst_n    : in  std_logic;
    entrada_qt    : in  std_logic_vector(LARGURA_ENTRADA_INT-1 downto 0);
    entrada_valid : in  std_logic;
    saida_qt      : out std_logic_vector(LARGURA_SAIDA_INT + LARGURA_SAIDA_FRAC-1 downto 0);
    saida_valid   : out std_logic);

end entity log2_mitchel;

architecture fpga of log2_mitchel is
  constant LARGURA_ENTRADA : integer := LARGURA_ENTRADA_INT;
  constant ENTRADA_MSB     : integer := LARGURA_ENTRADA-1;

  constant SAIDA_MSB      : integer := LARGURA_SAIDA_INT+ LARGURA_SAIDA_FRAC-1;
  constant SAIDA_INT_MSB  : integer := LARGURA_SAIDA_INT+ LARGURA_SAIDA_FRAC-1;
  constant SAIDA_INT_LSB  : integer := LARGURA_SAIDA_FRAC;
  constant SAIDA_FRAC_MSB : integer := LARGURA_SAIDA_FRAC-1;
  constant SAIDA_FRAC_LSB : integer := 0;

  subtype lut_addr_t is unsigned(PRECISAO_ENTRADA_LUT-1 downto 0);
  subtype log2_entrada_t is unsigned(ENTRADA_MSB downto 0);
  subtype log2_saida_int_t is unsigned(LARGURA_SAIDA_INT-1 downto 0);
  subtype log2_saida_frac_t is unsigned(LARGURA_SAIDA_FRAC-1 downto 0);
  subtype log2_saida_t is unsigned(SAIDA_MSB downto 0);

  constant NUM_ENTRADAS_LUT_LOG2 : integer := 2**PRECISAO_ENTRADA_LUT;
  type log2_lut_t is array (0 to NUM_ENTRADAS_LUT_LOG2-1) of log2_saida_frac_t;

  type flop_in_t is record
    entrada_qt    : log2_entrada_t;
    entrada_valid : std_logic;
  end record flop_in_t;
  constant DEF_FLOP_IN : flop_in_t := (
    entrada_qt    => (others => '0'),
    entrada_valid => '0');
  signal flop_in : flop_in_t := DEF_FLOP_IN;

  type flop_encoder_t is record
    entrada_qt : log2_entrada_t;
    encoded_k  : log2_saida_int_t;
    valid      : std_logic;
  end record flop_encoder_t;
  constant DEF_FLOP_ENCODER : flop_encoder_t := (
    entrada_qt => (others => '0'),
    encoded_k  => (others => '0'),
    valid      => '0');
  signal flop_encoder : flop_encoder_t := DEF_FLOP_ENCODER;

  type flop_shifter_t is record
    shifted_out : lut_addr_t;
    encoded_k   : log2_saida_int_t;
    valid       : std_logic;
  end record flop_shifter_t;
  constant DEF_FLOP_SHIFTER : flop_shifter_t := (
    shifted_out => (others => '0'),
    encoded_k   => (others => '0'),
    valid       => '0');
  signal flop_shifter : flop_shifter_t := DEF_FLOP_SHIFTER;

  type flop_lut_pesquisa_t is record
    log_frac  : log2_saida_frac_t;
    encoded_k : log2_saida_int_t;
    valid     : std_logic;
  end record flop_lut_pesquisa_t;
  constant DEF_FLOP_LUT_PESQUISA : flop_lut_pesquisa_t := (
    log_frac  => (others => '0'),
    encoded_k => (others => '0'),
    valid     => '0');
  signal flop_lut_pesquisa : flop_lut_pesquisa_t := DEF_FLOP_LUT_PESQUISA;

  constant CONSTANTE_1_SAIDA : log2_saida_t := ((LARGURA_SAIDA_FRAC-1) => '1', others => '0');

  constant CONSTANT_0_SAIDA_INT  : log2_saida_int_t  := (others => '0');
  constant CONSTANT_0_SAIDA_FRAC : log2_saida_frac_t := (others => '0');

  -- purpose: Preenche a lut
  -- O valor da lut é do formato:
  -- lut(i) = log2(1+i/num_entradas)
  function preenche_lut_log2
    return log2_lut_t is
    variable lut_aux        : log2_lut_t;
    variable curr_f, log2_f : real;
  begin  -- function preenche_lut_log2
    for i in 0 to NUM_ENTRADAS_LUT_LOG2-1 loop
      curr_f     := real(i)/real(NUM_ENTRADAS_LUT_LOG2);
      log2_f     := log2(1.0 + curr_f)*real(2.0**LARGURA_SAIDA_FRAC);
      lut_aux(i) := to_unsigned(integer(log2_f), LARGURA_SAIDA_FRAC);
    end loop;  -- i
    return lut_aux;
  end function preenche_lut_log2;

  -- purpose: Acha o bit mais alto do valor da entrada e retorna a posicao dele
  function acha_bit_mais_alto (
    valor_in : unsigned)
    return unsigned is
    variable pos_bit_alto : integer := 0;
  begin  -- function acha_bit_mais_alto
    pos_bit_alto := 0;
    for i in 0 to LARGURA_ENTRADA-1 loop
      if '1' = valor_in(i) then
        pos_bit_alto := i;
      end if;
    end loop;  -- i in LARGURA_ENTRADA_FRAC to LARGURA_ENTRADA
    return to_unsigned(pos_bit_alto, LARGURA_SAIDA_INT);
  end function acha_bit_mais_alto;

  -- purpose: Shifta a entrada por shift_count bits para a direita,
  -- Retorna os valores nos bits fracionarios da entrada
  function shifta_entrada (
    valor_in    : unsigned(LARGURA_ENTRADA-1 downto 0);
    shift_count : unsigned)
    return lut_addr_t is
    variable shift_count_int  : integer;
    variable shifter_aux      : unsigned(LARGURA_ENTRADA+PRECISAO_ENTRADA_LUT-1 downto 0);
  begin  -- function shifta_entrada
    shift_count_int := to_integer(shift_count);
    shifter_aux(shifter_aux'high downto PRECISAO_ENTRADA_LUT) :=
      valor_in;
    shifter_aux(PRECISAO_ENTRADA_LUT-1 downto 0) := (others => '0');

    shifter_aux := shift_right(shifter_aux, shift_count_int);
    -- o resultado shiftado devera caber todo na parte fracional do
    -- registrador de entrada que e f      
    return shifter_aux(PRECISAO_ENTRADA_LUT-1 downto 0);
  end function shifta_entrada;

  -- purpose: Acha o bit mais alto e shifta o valor de entrada pelo numero de bits da posicao
  procedure decompoe_log (
    signal valor_in       : in  unsigned;
    signal pos_bit_alto   : out unsigned;
    signal valor_shiftado : out unsigned) is
    variable shift_count : log2_saida_int_t;
    variable shifted_out : lut_addr_t;
  begin  -- procedure decompoe_log
    shift_count := acha_bit_mais_alto(valor_in);
    shifted_out := shifta_entrada(valor_in, shift_count);

    pos_bit_alto   <= shift_count;
    valor_shiftado <= shifted_out;
    
  end procedure decompoe_log;
  -- purpose: Soma a parte fracional e inteiras da para compor a saida
  function compoe_saida (
    parte_inteira   : log2_saida_int_t;
    parte_fracional : log2_saida_frac_t)
    return log2_saida_t is
  begin  -- function compoe_saida
    return (parte_inteira & parte_fracional);
  end function compoe_saida;
  signal lut_log2 : log2_lut_t := preenche_lut_log2;
begin  -- architecture fpga

-- purpose: Implementa o pipeline para calcular o log
-- type   : sequential
-- inputs : clk, rst_n, entrada_qt, entrada_valid
-- outputs: saida_qt, saida_valid
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_prock
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_in           <= DEF_FLOP_IN;
      flop_encoder      <= DEF_FLOP_ENCODER;
      flop_shifter      <= DEF_FLOP_SHIFTER;
      flop_lut_pesquisa <= DEF_FLOP_LUT_PESQUISA;

    --saida_qt    <= (others => '0');
    --saida_valid <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- Recebe entradas
      flop_in.entrada_qt    <= unsigned(entrada_qt);
      flop_in.entrada_valid <= entrada_valid;

      -- Primeiro estagio, calcula o valor de k (veja descricao) e shifta entrada
      -- qt para achar N>>k
      flop_shifter.valid <= flop_in.entrada_valid;
      decompoe_log(flop_in.entrada_qt, flop_shifter.encoded_k,
                   flop_shifter.shifted_out);

      -- pesquisa o valor de log2(1+f) na lut
      flop_lut_pesquisa.encoded_k <= flop_shifter.encoded_k;
      flop_lut_pesquisa.log_frac  <= lut_log2(to_integer(flop_shifter.shifted_out));
      flop_lut_pesquisa.valid     <= flop_shifter.valid;

      
    end if;

  end process clk_proc;
  -- realiza: log2(N) =  k + log2(1+f)
  saida_qt <= std_logic_vector(compoe_saida(flop_lut_pesquisa.encoded_k,
                                            flop_lut_pesquisa.log_frac));
  saida_valid <= flop_lut_pesquisa.valid;

end architecture fpga;
