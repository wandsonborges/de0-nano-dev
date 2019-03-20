-------------------------------------------------------------------------------
-- Title      : calc_mi
-- Project    : 
-------------------------------------------------------------------------------
-- File       : calc_mi.vhd
-- Author     :   <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-10-11
-- Last update: 2014-08-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementacao do algoritmo de mutual information
--              Esse algoritmo calcula o valor de mutual information entre duas
--              imagens, a partir do histograma das duas.
--              Para tal: mi = sum( (hist_2d(p,q)/total_pixels) *(
--                        log2(hist(p)) - log2(total_angulos)  ), para todo
--                        p,q nos histogramas.
--              Alteracoes feitas no algoritmo original:
--              O log2 foi reescrito uma soma de log2 para evitar divisoes e multiplicacoes
--              mi tem que ser calculado n vezes e o maior valor selecionado, a
--              saida do algoritmo eh o indice do maior valor
--              
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-10-11  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.uteis.all;
use work.megafunc_pkg.all;
--use work.depuracao.all;

library lpm;

use lpm.all;
use lpm.lpm_components.all;

entity calc_mi is
  
  generic (
    NUMERO_BINS           : integer := 16;
    LARGURA_ADDR_BINS     : integer := 4;
    NUMERO_HISTOGRAMAS    : integer := 32;
    LARGURA_N_HISTOGRAMAS : integer := 5;
    LARGURA_BINS          : integer := 16;
    LARGURA_LOG_BIN       : integer := 5;
    LOG_OUT_FRAC_N_BITS   : integer := 12;
    NUMERO_PIXELS_QUADRO  : integer := 320*256;
    LARGURA_N_PIXEIS      : integer := 17;
    LARGURA_MI_OUT        : integer := 27;
    DEBUG                 : boolean := false);

  port (
    clk, rst_n         : in  std_logic;
    hist_fxd_bin_addr  : out std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    hist_flt_bin_addr  : out std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    hist_fxd_qt        : in  std_logic_vector(LARGURA_BINS-1 downto 0);
    hist_flt_qt        : in  std_logic_vector(LARGURA_BINS-1 downto 0);
    hist_h2d_qt        : in  std_logic_vector(LARGURA_BINS-1 downto 0);
    hist_shift_one_hot : out std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    hist_rd_en         : out std_logic;
    prox_shift         : in  std_logic;
    curr_mi_out        : out std_logic_vector(LARGURA_MI_OUT-1 downto 0);
    curr_mi_out_valido : out std_logic);

end entity calc_mi;

architecture fpga of calc_mi is
  attribute multstyle         : string;
  attribute multstyle of fpga : architecture is "dsp";


  constant LARGURA_BINS_I  : integer := LARGURA_BINS;
  constant LOG2_NUM_PIXELS : integer :=
    integer(log2(real(NUMERO_PIXELS_QUADRO))*real((2**LOG_OUT_FRAC_N_BITS)));

  type mi_estado_t is (ST_OCIOSO, ST_LOOP_HIST, ST_ESPERA_PROX);
  constant N_CICLOS_LOG2    : integer := 4;
  subtype hist_qt_t is unsigned(LARGURA_BINS_I-1 downto 0);
  subtype log2_out_t is unsigned(LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS-1 downto 0);
  constant LARGURA_LOG_SOMA : integer := LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS+3;
  subtype log2_sums_out_t is signed(LARGURA_LOG_SOMA-1 downto 0);
  constant LARGURA_MULT     : integer
    := LARGURA_LOG_BIN+LARGURA_BINS_I+4+LOG_OUT_FRAC_N_BITS;
  subtype log2_mult_out_t is signed(LARGURA_MULT-1 downto 0);
  constant LARGURA_ACCUM : integer
    := LARGURA_LOG_BIN+LARGURA_BINS_I+LARGURA_ADDR_BINS+4+LOG_OUT_FRAC_N_BITS;
  subtype mi_accum_t is signed(LARGURA_ACCUM-1 downto 0);

  signal hist_h2d_log_in_qt, hist_fxd_log_in_qt, hist_flt_log_in_qt :
    std_logic_vector(LARGURA_BINS_I-1 downto 0) := (others => '0');

  signal hist_h2d_log_out_qt, hist_fxd_log_out_qt, hist_flt_log_out_qt :
    std_logic_vector(LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS-1 downto 0) := (others => '0');

  type log2_espera_t is record
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
    hist_zero         : std_logic;
    hist_pct          : hist_qt_t;
  end record log2_espera_t;
  type log2_espera_fila_t is array (0 to N_CICLOS_LOG2-1) of log2_espera_t;
  constant DEF_LOG2_ESPERA : log2_espera_t := (
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0',
    hist_zero         => '0',
    hist_pct          => (others => '0'));
  signal log2_ciclo_extra0      : log2_espera_t      := DEF_LOG2_ESPERA;
  constant DEF_LOG2_ESPERA_FILA : log2_espera_fila_t := (others => DEF_LOG2_ESPERA);
  signal log2_espera_fila       : log2_espera_fila_t := DEF_LOG2_ESPERA_FILA;

  type controle_t is record
    estado             : mi_estado_t;
    comeco_calculo     : std_logic;
    hist_rd_en         : std_logic;
    hist_shift_addr    : unsigned(LARGURA_N_HISTOGRAMAS-1 downto 0);
    hist_fxd_bin_addr  : unsigned(LARGURA_ADDR_BINS-1 downto 0);
    hist_flt_bin_addr  : unsigned(LARGURA_ADDR_BINS-1 downto 0);
    hist_shift_one_hot : unsigned(NUMERO_HISTOGRAMAS-1 downto 0);
    primeira_iteracao  : std_logic;
    ultima_iteracao    : std_logic;
  end record controle_t;
  
  constant DEF_CONTROLE : controle_t := (
    estado             => ST_OCIOSO,
    comeco_calculo     => '0',
    hist_rd_en         => '0',
    hist_shift_addr    => (others => '0'),
    hist_shift_one_hot => (others => '0'),
    hist_fxd_bin_addr  => (others => '0'),
    hist_flt_bin_addr  => (others => '0'),
    primeira_iteracao  => '0',
    ultima_iteracao    => '0');
  signal controle : controle_t := DEF_CONTROLE;

  type flop_init_t is record
    hist_flt_qt : hist_qt_t;
    hist_fxd_qt : hist_qt_t;
    hist_h2d_qt : hist_qt_t;
    prox_shift  : std_logic;
  end record flop_init_t;
  constant DEF_FLOP_INIT : flop_init_t := (
    hist_flt_qt => (others => '0'),
    hist_fxd_qt => (others => '0'),
    hist_h2d_qt => (others => '0'),
    prox_shift  => '0');
  signal flop_init : flop_init_t := DEF_FLOP_INIT;

  type flop_log_out_t is record
    hist_flt_log      : log2_out_t;
    hist_fxd_log      : log2_out_t;
    hist_h2d_log      : log2_out_t;
    hist_pct          : hist_qt_t;
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
  end record flop_log_out_t;
  constant DEF_FLOP_LOG_OUT : flop_log_out_t := (
    hist_flt_log      => (others => '0'),
    hist_fxd_log      => (others => '0'),
    hist_h2d_log      => (others => '0'),
    hist_pct          => (others => '0'),
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0');

  signal flop_log_out : flop_log_out_t;

  type flop_log_soma_t is record
    log_soma_out      : log2_sums_out_t;
    hist_pct          : hist_qt_t;
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
  end record flop_log_soma_t;
  constant DEF_FLOP_LOG_SOMA : flop_log_soma_t := (
    log_soma_out      => (others => '0'),
    hist_pct          => (others => '0'),
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0');
  signal flop_log_soma : flop_log_soma_t := DEF_FLOP_LOG_SOMA;

  type flop_log_mult_t is record
    log_mult_out    : log2_mult_out_t;
    accum           : mi_accum_t;
    ultima_iteracao : std_logic;
    comeco_calculo  : std_logic;
    primeira_iteracao : std_logic;
  end record flop_log_mult_t;
  constant DEF_FLOP_LOG_MULT : flop_log_mult_t := (
    log_mult_out    => (others => '0'),
    accum           => (others => '0'),
    ultima_iteracao => '0',
    comeco_calculo  => '0',
    primeira_iteracao => '0');
  signal flop_log_mult : flop_log_mult_t := DEF_FLOP_LOG_MULT;

  type flop_mi_update_t is record
    ultima_iteracao : std_logic;
    accum           : mi_accum_t;
  end record flop_mi_update_t;
  constant DEF_FLOP_MI_UPDATE : flop_mi_update_t := (
    ultima_iteracao => '0',
    accum           => (others => '0'));
  signal flop_mi_update : flop_mi_update_t := DEF_FLOP_MI_UPDATE;


  -- purpose: Calcula o reciproco do total de pixeis
  function get_recip_total_pixels
    return hist_qt_t is
    variable recip_real : real;
    variable recip_fp   : hist_qt_t;
  begin  -- function get_recip_total_pixels
    assert NUMERO_PIXELS_QUADRO > 2**(LARGURA_N_PIXEIS-1) report "O reciproco do numero de pixeis do quadro vai causar um estouro. Tente utilizar menos pixeis para representar esse numero" severity failure;
    recip_real := (1.0/real(NUMERO_PIXELS_QUADRO))*
                  real(2.0**(LARGURA_BINS_I+LARGURA_N_PIXEIS-1));
    recip_fp := to_unsigned(integer(recip_real), LARGURA_BINS_I);
    return recip_fp;
  end function get_recip_total_pixels;

  constant recip_total_pixels : unsigned(LARGURA_BINS_I-1 downto 0)
    := get_recip_total_pixels;

  function get_hist_pct (
    signal hist_value           : hist_qt_t;
    constant recip_total_pixels : hist_qt_t)
    return hist_qt_t is
    variable mult_out       : unsigned(2*LARGURA_BINS_I-1 downto 0);
    variable mult_truncated : unsigned(2*LARGURA_BINS_I-1 downto 0);
  begin
    mult_out       := recip_total_pixels*hist_value;
    mult_truncated := mult_out/(2**(LARGURA_N_PIXEIS+LARGURA_BINS_I-16-1));
    return mult_truncated(LARGURA_BINS_I-1 downto 0);
  end function get_hist_pct;

begin  -- architecture fpga

  -- purpose: Processo sequencial
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      controle           <= DEF_CONTROLE;
      flop_init          <= DEF_FLOP_INIT;
      log2_espera_fila   <= DEF_LOG2_ESPERA_FILA;
      flop_log_out       <= DEF_FLOP_LOG_OUT;
      flop_log_soma      <= DEF_FLOP_LOG_SOMA;
      flop_log_mult      <= DEF_FLOP_LOG_MULT;
      flop_mi_update     <= DEF_FLOP_MI_UPDATE;
      log2_ciclo_extra0  <= DEF_LOG2_ESPERA;

      curr_mi_out_valido <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- escreve valores defauts em nessa variavel, senao o sintetizador
      -- infere latch
      log2_ciclo_extra0 <= DEF_LOG2_ESPERA;

      -- flop que le os dados iniciais
      if '1' = controle.hist_rd_en then
        flop_init.hist_h2d_qt <= unsigned(hist_h2d_qt);
        flop_init.hist_fxd_qt <= unsigned(hist_fxd_qt);
        flop_init.hist_flt_qt <= unsigned(hist_flt_qt);
      end if;

      flop_init.prox_shift <= prox_shift;

      controle.hist_rd_en        <= '0';
      controle.ultima_iteracao   <= '0';
      controle.primeira_iteracao <= '0';
      controle.comeco_calculo    <= '0';


      -- maquina de estado que controla o pipeline
      case controle.estado is
        when ST_OCIOSO =>
          if '1' = flop_init.prox_shift then
            controle.estado             <= ST_LOOP_HIST;
            controle.hist_shift_addr    <= (others => '0');
            controle.hist_flt_bin_addr  <= (others => '0');
            controle.hist_fxd_bin_addr  <= (others => '0');
            controle.hist_shift_one_hot <= (0      => '1', others => '0');
            controle.hist_rd_en         <= '1';
            controle.primeira_iteracao  <= '1';
            controle.comeco_calculo     <= '1';
          end if;
        when ST_LOOP_HIST =>
          controle.hist_flt_bin_addr <= controle.hist_flt_bin_addr + 1;
          if controle.hist_flt_bin_addr = NUMERO_BINS-1 then
            controle.hist_flt_bin_addr <= (others => '0');
            controle.hist_fxd_bin_addr <= controle.hist_fxd_bin_addr + 1;
          end if;


          controle.hist_rd_en <= '1';
          -- penultimo ciclo, marca que o proximo e o ultimo
          if (controle.hist_flt_bin_addr = NUMERO_BINS-2) and
            (controle.hist_fxd_bin_addr = NUMERO_BINS-1) then
            controle.ultima_iteracao <= '1';
          -- fim do frame shift
          elsif (controle.hist_flt_bin_addr = NUMERO_BINS-1) and
            (controle.hist_fxd_bin_addr = NUMERO_BINS-1) then
            if controle.hist_shift_addr = NUMERO_HISTOGRAMAS-1 then
              controle.estado          <= ST_OCIOSO;
              controle.hist_shift_addr <= (others => '0');
            else
              controle.estado <= ST_ESPERA_PROX;
            end if;
          end if;
        when ST_ESPERA_PROX =>
          if '1' = prox_shift then
            controle.estado             <= ST_LOOP_HIST;
            -- proximo ciclo sera o inicio de uma nova iteraco
            controle.primeira_iteracao  <= '1';
            controle.hist_flt_bin_addr  <= (others => '0');
            controle.hist_fxd_bin_addr  <= (others => '0');
            controle.hist_rd_en         <= '1';
            -- fim do numero de shifts
            controle.hist_shift_addr    <= controle.hist_shift_addr+1;
            controle.hist_shift_one_hot <= shift_left(controle.hist_shift_one_hot, 1);
          end if;

        when others => null;
      end case;


      -- coloca sinais na fila para compensar o atraso do calculo de log2 dos outros
      -- valores de histograma
      if '1' = controle.hist_rd_en then
        if (0 = unsigned(hist_h2d_qt)) or
          (0 = unsigned(hist_fxd_qt)) or
          (0 = unsigned(hist_flt_qt))
        then
          log2_espera_fila(0).hist_zero <= '1';
        else
          log2_espera_fila(0).hist_zero <= '0';
        end if;

        --sinais de controle esperam um ciclo a mais para compensar
        --a latencia de leitura da memoria
        log2_ciclo_extra0.primeira_iteracao <= controle.primeira_iteracao;
        log2_ciclo_extra0.ultima_iteracao   <= controle.ultima_iteracao;
        log2_ciclo_extra0.comeco_calculo    <= controle.comeco_calculo;
      end if;

      log2_espera_fila(0).primeira_iteracao <= log2_ciclo_extra0.primeira_iteracao;
      log2_espera_fila(0).ultima_iteracao   <= log2_ciclo_extra0.ultima_iteracao;
      log2_espera_fila(0).comeco_calculo    <= log2_ciclo_extra0.comeco_calculo;
      log2_espera_fila(0).hist_pct <= get_hist_pct(flop_init.hist_h2d_qt,
                                                   recip_total_pixels);
      --log2_espera_fila(0).hist_pct <= get_hist_pct(hist_2d_unsigned,
      --                                             recip_total_pixels);
      -- Fila que guarda os valores enquanto log2 eh calculado
      for i in 1 to N_CICLOS_LOG2-1 loop
        log2_espera_fila(i) <= log2_espera_fila(i-1);
      end loop;  -- i

      flop_log_out.primeira_iteracao <= log2_espera_fila(N_CICLOS_LOG2-1).primeira_iteracao;
      flop_log_out.ultima_iteracao   <= log2_espera_fila(N_CICLOS_LOG2-1).ultima_iteracao;
      flop_log_out.comeco_calculo    <= log2_espera_fila(N_CICLOS_LOG2-1).comeco_calculo;
      flop_log_out.hist_pct          <= log2_espera_fila(N_CICLOS_LOG2-1).hist_pct;
      flop_log_out.hist_h2d_log      <= unsigned(hist_h2d_log_out_qt);
      flop_log_out.hist_fxd_log      <= unsigned(hist_fxd_log_out_qt);
      flop_log_out.hist_flt_log      <= unsigned(hist_flt_log_out_qt);


      -- Primeiro estagio do pipeline depois do calculo do log - soma os
      -- resultados dos logs
      flop_log_soma.log_soma_out <=
        (signed("000" & flop_log_out.hist_h2d_log) +
         to_signed(LOG2_NUM_PIXELS, LARGURA_LOG_SOMA)) -
        (signed("000" & flop_log_out.hist_fxd_log) +
         signed("000" & flop_log_out.hist_flt_log));

      flop_log_soma.primeira_iteracao <= flop_log_out.primeira_iteracao;
      flop_log_soma.ultima_iteracao   <= flop_log_out.ultima_iteracao;
      flop_log_soma.comeco_calculo    <= flop_log_out.comeco_calculo;

      --marretada - consertar depois
      flop_log_soma.hist_pct     <= log2_espera_fila(N_CICLOS_LOG2-1).hist_pct;
      --flop_log_soma.hist_pct <= flop_log_out.hist_pct;
      -- Segundo estagio multiplicacao das somas
      flop_log_mult.log_mult_out <= signed('0' & flop_log_soma.hist_pct) *
                                    flop_log_soma.log_soma_out;

      flop_log_mult.primeira_iteracao <= flop_log_soma.primeira_iteracao;
      if '1' = flop_log_mult.primeira_iteracao then
        flop_log_mult.accum <= resize(flop_log_mult.log_mult_out, LARGURA_ACCUM);
      else
        flop_log_mult.accum <= flop_log_mult.accum + flop_log_mult.log_mult_out;
      end if;
      flop_log_mult.ultima_iteracao <= flop_log_soma.ultima_iteracao;
      flop_log_mult.comeco_calculo  <= flop_log_soma.comeco_calculo;

      -- Terceiro estagio update do valor atual de mutual information
      if '1' = flop_mi_update.ultima_iteracao then
        flop_mi_update.accum <= flop_log_mult.accum;
      end if;
      flop_mi_update.ultima_iteracao <= flop_log_mult.ultima_iteracao;

      curr_mi_out_valido <= flop_mi_update.ultima_iteracao;
      
      
    end if;

  end process clk_proc;

  -- Quarto estagio, seleciona o maior valor do mutual information e faz a
  -- saida
  curr_mi_out
    <= std_logic_vector(resize(flop_mi_update.accum(LARGURA_ACCUM-1 downto LOG_OUT_FRAC_N_BITS),
                               LARGURA_MI_OUT));


  hist_h2d_log_in_qt <= std_logic_vector(flop_init.hist_h2d_qt);
  log2_hist_h2d : entity work.log2_mitchel
    generic map (
      LARGURA_ENTRADA_INT  => LARGURA_BINS_I,
      LARGURA_SAIDA_INT    => LARGURA_LOG_BIN,
      LARGURA_SAIDA_FRAC   => LOG_OUT_FRAC_N_BITS)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      entrada_qt    => hist_h2d_log_in_qt,
      entrada_valid => '1',
      saida_qt      => hist_h2d_log_out_qt,
      saida_valid   => open);

  hist_fxd_log_in_qt <= std_logic_vector(flop_init.hist_fxd_qt);
  log2_fxd_hist : entity work.log2_mitchel
    generic map (
      LARGURA_ENTRADA_INT  => LARGURA_BINS_I,
      LARGURA_SAIDA_INT    => LARGURA_LOG_BIN,
      LARGURA_SAIDA_FRAC   => LOG_OUT_FRAC_N_BITS)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      entrada_qt    => hist_fxd_log_in_qt,
      entrada_valid => '1',
      saida_qt      => hist_fxd_log_out_qt,
      saida_valid   => open);

  hist_flt_log_in_qt <= std_logic_vector(flop_init.hist_flt_qt);
  log2_flt_hist : entity work.log2_mitchel
    generic map (
      LARGURA_ENTRADA_INT  => LARGURA_BINS_I,
      LARGURA_SAIDA_INT    => LARGURA_LOG_BIN,
      LARGURA_SAIDA_FRAC   => LOG_OUT_FRAC_N_BITS)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      entrada_qt    => hist_flt_log_in_qt,
      entrada_valid => '1',
      saida_qt      => hist_flt_log_out_qt,
      saida_valid   => open);

  hist_flt_bin_addr  <= std_logic_vector(controle.hist_flt_bin_addr);
  hist_fxd_bin_addr  <= std_logic_vector(controle.hist_fxd_bin_addr);
  hist_rd_en         <= controle.hist_rd_en;
  hist_shift_one_hot <= std_logic_vector(controle.hist_shift_one_hot);


end architecture fpga;
