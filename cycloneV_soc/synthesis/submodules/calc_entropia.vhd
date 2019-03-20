-------------------------------------------------------------------------------
-- Title      : calc_entropia
-- Project    : 
-------------------------------------------------------------------------------
-- File       : calc_entropia.vhd
-- Author     :   <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-10-11
-- Last update: 2014-08-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementacao do algoritmo de entropia
--              Esse algoritmo calcula o valor de entropia entre duas
--              imagens, a partir do histograma das duas.
--              Para tal: ent = sum( (hist(p)/total_angulos) *(
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

use work.uteis.all;
use work.megafunc_pkg.all;

library lpm;

use lpm.all;
use lpm.lpm_components.all;

entity calc_entropia is
  
  generic (
    NUMERO_BINS           : integer := 16;
    LARGURA_ADDR_BINS     : integer := 4;
    NUMERO_HISTOGRAMAS    : integer := 32;
    LARGURA_N_HISTOGRAMAS : integer := 5;
    LARGURA_BINS          : integer := 16;
    LARGURA_LOG_BIN       : integer := 5;
    LOG_OUT_FRAC_N_BITS   : integer := 12;
    LARGURA_ENTROPIA_OUT  : integer := 27);

  port (
    clk, rst_n         : in  std_logic;
    hist_bin_addr      : out std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    hist_qt            : in  std_logic_vector(LARGURA_BINS-1 downto 0);
    hist_shift_one_hot : out std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    hist_rd_en         : out std_logic;
    total_angulos      : in  std_logic_vector(LARGURA_BINS-1 downto 0);
    prox_shift         : in  std_logic;

    curr_mi_out        : out std_logic_vector(LARGURA_ENTROPIA_OUT-1 downto 0);
    curr_mi_out_valido : out std_logic);

end entity calc_entropia;

architecture fpga of calc_entropia is
  attribute multstyle         : string;
  attribute multstyle of fpga : architecture is "dsp";

  type mi_estado_t is (ST_OCIOSO, ST_LOOP_HIST, ST_ESPERA_PROX);
  constant N_CICLOS_LOG2  : integer := 4;
  constant LARGURA_BINS_I : integer := LARGURA_BINS;
  subtype hist_qt_t is unsigned(LARGURA_BINS_I-1 downto 0);
  subtype log2_out_t is unsigned(LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS-1 downto 0);
  subtype log2_sums_out_t is signed((LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS+2) downto 0);
  constant LARGURA_MULT   : integer
    := LARGURA_LOG_BIN+LARGURA_BINS_I+4+LOG_OUT_FRAC_N_BITS;
  subtype log2_mult_out_t is signed(LARGURA_MULT-1 downto 0);
  constant LARGURA_ACCUM : integer
    := LARGURA_LOG_BIN+LARGURA_BINS_I+LARGURA_ADDR_BINS+4+LOG_OUT_FRAC_N_BITS;
  subtype mi_accum_t is signed(LARGURA_ACCUM-1 downto 0);


  signal hist_log_in_qt          : std_logic_vector(LARGURA_BINS_I-1 downto 0) := (others => '0');
  signal total_angulos_log_in_qt : std_logic_vector(LARGURA_BINS_I-1 downto 0) := (others => '0');

  signal hist_log_out_qt : std_logic_vector(LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS-1 downto 0)
    := (others => '0');
  signal total_angulos_log_out_qt : std_logic_vector(LARGURA_LOG_BIN+LOG_OUT_FRAC_N_BITS-1 downto 0)
    := (others => '0');

  type log2_espera_t is record
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
    hist_zero         : std_logic;
  end record log2_espera_t;
  type log2_espera_fila_t is array (0 to N_CICLOS_LOG2-1) of log2_espera_t;
  constant DEF_LOG2_ESPERA : log2_espera_t := (
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0',
    hist_zero         => '0');
  signal log2_ciclo_extra0      : log2_espera_t      := DEF_LOG2_ESPERA;
  constant DEF_LOG2_ESPERA_FILA : log2_espera_fila_t := (others => DEF_LOG2_ESPERA);
  signal log2_espera_fila       : log2_espera_fila_t := DEF_LOG2_ESPERA_FILA;

  constant N_CICLOS_DIV        : integer := 20;
  constant N_CICLOS_ESPERA_DIV : integer := N_CICLOS_DIV-N_CICLOS_LOG2-1;
  type div_espera_t is record
    hist_log          : log2_out_t;
    total_angulos_log : log2_out_t;
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
  end record div_espera_t;
  constant DEF_DIV_ESPERA : div_espera_t := (
    hist_log          => (others => '0'),
    total_angulos_log => (others => '0'),
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0');
  type div_espera_fila_t is array (0 to N_CICLOS_ESPERA_DIV-1) of div_espera_t;
  signal div_espera_fila : div_espera_fila_t := (others => DEF_DIV_ESPERA);

  type controle_t is record
    estado             : mi_estado_t;
    comeco_calculo     : std_logic;
    hist_rd_en         : std_logic;
    hist_shift_addr    : unsigned(LARGURA_N_HISTOGRAMAS-1 downto 0);
    hist_bin_addr      : unsigned(LARGURA_ADDR_BINS-1 downto 0);
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
    hist_bin_addr      => (others => '0'),
    primeira_iteracao  => '0',
    ultima_iteracao    => '0');
  signal controle : controle_t := DEF_CONTROLE;

  type flop_init_t is record
    hist_qt    : hist_qt_t;
    prox_shift : std_logic;
  end record flop_init_t;
  constant DEF_FLOP_INIT : flop_init_t := (
    hist_qt    => (others => '0'),
    prox_shift => '0');
  signal flop_init : flop_init_t := DEF_FLOP_INIT;

  type flop_log_out_t is record
    hist_log          : log2_out_t;
    total_angulos_log : log2_out_t;
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
  end record flop_log_out_t;
  constant DEF_FLOP_LOG_OUT : flop_log_out_t := (
    hist_log          => (others => '0'),
    total_angulos_log => (others => '0'),
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0');

  signal flop_log_out : flop_log_out_t;

  type flop_log_soma_t is record
    log_soma_out      : log2_sums_out_t;
    primeira_iteracao : std_logic;
    ultima_iteracao   : std_logic;
    comeco_calculo    : std_logic;
  end record flop_log_soma_t;
  constant DEF_FLOP_LOG_SOMA : flop_log_soma_t := (
    log_soma_out      => (others => '0'),
    primeira_iteracao => '0',
    ultima_iteracao   => '0',
    comeco_calculo    => '0');
  signal flop_log_soma : flop_log_soma_t := DEF_FLOP_LOG_SOMA;

  type flop_log_mult_t is record
    log_mult_out    : log2_mult_out_t;
    accum           : mi_accum_t;
    ultima_iteracao : std_logic;
    comeco_calculo  : std_logic;
  end record flop_log_mult_t;
  constant DEF_FLOP_LOG_MULT : flop_log_mult_t := (
    log_mult_out    => (others => '0'),
    accum           => (others => '0'),
    ultima_iteracao => '0',
    comeco_calculo  => '0');
  signal flop_log_mult : flop_log_mult_t := DEF_FLOP_LOG_MULT;

  type flop_mi_update_t is record
    ultima_iteracao : std_logic;
    accum           : mi_accum_t;
  end record flop_mi_update_t;
  constant DEF_FLOP_MI_UPDATE : flop_mi_update_t := (
    ultima_iteracao => '0',
    accum           => (others => '0'));
  signal flop_mi_update : flop_mi_update_t := DEF_FLOP_MI_UPDATE;


  constant LARGURA_DIVISOR_NUMERADOR   : integer := 2*LARGURA_BINS_I;
  constant LARGURA_DIVISOR_DENOMINADOR : integer := LARGURA_BINS_I;
  signal numerador_in, quociente_out   : std_logic_vector(LARGURA_DIVISOR_NUMERADOR-1 downto 0);
  signal denominador_in                : std_logic_vector(LARGURA_DIVISOR_DENOMINADOR-1 downto 0);
  
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
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- escreve valores defauts em nessa variavel, senao o sintetizador
      -- infere latch
      log2_ciclo_extra0 <= DEF_LOG2_ESPERA;

      -- flop que le os dados iniciais
      flop_init.hist_qt    <= unsigned(hist_qt);
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
            controle.hist_bin_addr      <= (others => '0');
            controle.hist_shift_one_hot <= (0      => '1', others => '0');
            controle.hist_rd_en         <= '1';
            controle.primeira_iteracao  <= '1';
            controle.comeco_calculo     <= '1';
          end if;
        when ST_LOOP_HIST =>
          controle.hist_bin_addr <= controle.hist_bin_addr + 1;
          controle.hist_rd_en    <= '1';

          -- fim do frame shift
          if controle.hist_bin_addr = NUMERO_BINS-1 then
            controle.ultima_iteracao <= '1';
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
            controle.hist_bin_addr      <= (others => '0');
            controle.hist_rd_en         <= '1';
            -- fim do numero de shifts
            controle.hist_shift_addr    <= controle.hist_shift_addr+1;
            controle.hist_shift_one_hot <= shift_left(controle.hist_shift_one_hot, 1);
          end if;

        when others => null;
      end case;

      --sinais de controle esperam um ciclo a mais para compensar
      --a latencia de leitura da memoria
      log2_ciclo_extra0.primeira_iteracao <= controle.primeira_iteracao;
      log2_ciclo_extra0.ultima_iteracao   <= controle.ultima_iteracao;
      log2_ciclo_extra0.comeco_calculo    <= controle.comeco_calculo;

      -- coloca sinais na fila para compensar o atraso do calculo de log2 dos outros
      -- valores de histograma
      if 0 = unsigned(hist_qt) then
        log2_espera_fila(0).hist_zero <= '1';
      else
        log2_espera_fila(0).hist_zero <= '0';
      end if;
      log2_espera_fila(0).primeira_iteracao <= log2_ciclo_extra0.primeira_iteracao;
      log2_espera_fila(0).ultima_iteracao   <= log2_ciclo_extra0.ultima_iteracao;
      log2_espera_fila(0).comeco_calculo    <= log2_ciclo_extra0.comeco_calculo;
      -- Fila que guarda os valores enquanto log2 eh calculado
      for i in 1 to N_CICLOS_LOG2-1 loop
        log2_espera_fila(i) <= log2_espera_fila(i-1);
      end loop;  -- i

      div_espera_fila(0).primeira_iteracao <= log2_espera_fila(N_CICLOS_LOG2-1).primeira_iteracao;
      div_espera_fila(0).ultima_iteracao   <= log2_espera_fila(N_CICLOS_LOG2-1).ultima_iteracao;
      div_espera_fila(0).comeco_calculo    <= log2_espera_fila(N_CICLOS_LOG2-1).comeco_calculo;

      -- Flopa os resultados dos logs
      if '0' = log2_espera_fila(N_CICLOS_LOG2-1).hist_zero then
        div_espera_fila(0).hist_log          <= unsigned(hist_log_out_qt);
        div_espera_fila(0).total_angulos_log <= unsigned(total_angulos_log_out_qt);
      else
        div_espera_fila(0).hist_log          <= (others => '0');
        div_espera_fila(0).total_angulos_log <= (others => '0');
      end if;

      -- Fila que guarda os valores enqaunto a divisao e calculada
      for i in 1 to N_CICLOS_ESPERA_DIV-1 loop
        div_espera_fila(i) <= div_espera_fila(i-1);
      end loop;  -- i

      flop_log_out.hist_log          <= div_espera_fila(N_CICLOS_ESPERA_DIV-1).hist_log;
      flop_log_out.total_angulos_log <= div_espera_fila(N_CICLOS_ESPERA_DIV-1).total_angulos_log;

      flop_log_out.primeira_iteracao <= div_espera_fila(N_CICLOS_ESPERA_DIV-1).primeira_iteracao;
      flop_log_out.ultima_iteracao   <= div_espera_fila(N_CICLOS_ESPERA_DIV-1).ultima_iteracao;
      flop_log_out.comeco_calculo    <= div_espera_fila(N_CICLOS_ESPERA_DIV-1).comeco_calculo;

      -- Primeiro estagio do pipeline depois do calculo do log - soma os
      -- resultados dos logs
      flop_log_soma.log_soma_out <=
        signed("000" & flop_log_out.hist_log) -
        signed("000" & flop_log_out.total_angulos_log);

      flop_log_soma.primeira_iteracao <= flop_log_out.primeira_iteracao;
      flop_log_soma.ultima_iteracao   <= flop_log_out.ultima_iteracao;
      flop_log_soma.comeco_calculo    <= flop_log_out.comeco_calculo;

      -- Segundo estagio multiplicacao das somas
      flop_log_mult.log_mult_out <= -resize(signed('0' & quociente_out(LARGURA_BINS_I-1 downto LARGURA_BINS_I-16)) *
                                    flop_log_soma.log_soma_out,LARGURA_MULT);
      if '1' = flop_log_soma.primeira_iteracao then
        flop_log_mult.accum <= (others => '0');
      else
        flop_log_mult.accum <= flop_log_mult.accum + flop_log_mult.log_mult_out;
      end if;
      flop_log_mult.ultima_iteracao <= flop_log_soma.ultima_iteracao;
      flop_log_mult.comeco_calculo  <= flop_log_soma.comeco_calculo;

      -- Terceiro estagio update do valor atual de entropia
      -- o bloco demora um ciclo extra para mutiplicar
      if '1' = flop_log_mult.ultima_iteracao then
        flop_mi_update.accum <= flop_log_mult.accum;
      end if;
      flop_mi_update.ultima_iteracao <= flop_log_mult.ultima_iteracao;



    end if;

  end process clk_proc;

  -- Quarto estagio, seleciona o maior valor do entropia e faz a
  -- saida
  curr_mi_out_valido <= flop_mi_update.ultima_iteracao;
  curr_mi_out
    <= std_logic_vector(resize(flop_mi_update.accum(LARGURA_ACCUM-1 downto LOG_OUT_FRAC_N_BITS),
                               LARGURA_ENTROPIA_OUT));

  hist_log_in_qt <= std_logic_vector(flop_init.hist_qt);
  log2_hist : entity work.log2_mitchel
    generic map (
      LARGURA_ENTRADA_INT  => LARGURA_BINS_I,
      LARGURA_SAIDA_INT    => LARGURA_LOG_BIN,
      LARGURA_SAIDA_FRAC   => LOG_OUT_FRAC_N_BITS)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      entrada_qt    => hist_log_in_qt,
      entrada_valid => '1',
      saida_qt      => hist_log_out_qt,
      saida_valid   => open);

  total_angulos_log_in_qt <= std_logic_vector(total_angulos);
  log2_total_angulos : entity work.log2_mitchel
    generic map (
      LARGURA_ENTRADA_INT  => LARGURA_BINS_I,
      LARGURA_SAIDA_INT    => LARGURA_LOG_BIN,
      LARGURA_SAIDA_FRAC   => LOG_OUT_FRAC_N_BITS)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      entrada_qt    => total_angulos_log_in_qt,
      entrada_valid => '1',
      saida_qt      => total_angulos_log_out_qt,
      saida_valid   => open);

  hist_bin_addr      <= std_logic_vector(controle.hist_bin_addr);
  hist_rd_en         <= controle.hist_rd_en;
  hist_shift_one_hot <= std_logic_vector(controle.hist_shift_one_hot);

  numerador_in(LARGURA_DIVISOR_NUMERADOR-1 downto LARGURA_DIVISOR_NUMERADOR-LARGURA_BINS_I)
    <= std_logic_vector(flop_init.hist_qt);
  numerador_in(LARGURA_DIVISOR_NUMERADOR-LARGURA_BINS_I-1 downto 0) <= (others => '0');

  denominador_in <= std_logic_vector(total_angulos);

  LPM_DIVIDE_1 : lpm.lpm_components.lpm_divide
    generic map (
      lpm_drepresentation => "UNSIGNED",
      lpm_hint            => "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "UNSIGNED",
      lpm_pipeline        => N_CICLOS_DIV,
      lpm_type            => "LPM_DIVIDE",
      lpm_widthd          => LARGURA_DIVISOR_DENOMINADOR,
      lpm_widthn          => LARGURA_DIVISOR_NUMERADOR
      )
    port map (
      clock    => clk,
      clken    => '1',
      denom    => denominador_in,
      numer    => numerador_in,
      remain   => open,
      quotient => quociente_out
      );

end architecture fpga;
