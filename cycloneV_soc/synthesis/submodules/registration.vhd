-------------------------------------------------------------------------------
-- Title      : registration
-- Project    : 
-------------------------------------------------------------------------------
-- File       : registration.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-28
-- Last update: 2018-05-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o algoritmo de registro
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 2013-11-28  1.0      mdrumond                Created
-- 2017-10-24  1.3      fernando.daldegan       Update -> Incluido controle pelo menu
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
entity registration is
  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    NUMERO_LINHAS            : integer := 256;
    LARGURA_CONTADOR_LINHAS  : integer := 9;
    LARGURA_N_HISTOGRAMAS    : integer := 5;
    LARGURA_N_PIXELS         : integer := 17;
    NUMERO_ITERACOES         : integer := 8;
    LARGURA_ITERACOES        : integer := 3;
    LARGURA_PASSO            : integer := 2;
    LARGURA_BINS             : integer := 16;
    LARGURA_ADDR_BINS        : integer := 4;
    DEBUG                    : boolean := false
    );
  port (
    clk, rst_n                               : in  std_logic;
    escolhe_metodo                           : in  std_logic_vector(1 downto 0);
    start_frame                              : in  std_logic;
    end_frame                                : out std_logic;
    fxd_pix_in, flt_pix_in                   : in  pixel_t;
    fxd_pix_rd_req, flt_pix_rd_req           : out std_logic;
    fxd_pix_rd_burst_en, flt_pix_rd_burst_en : in  std_logic;
    fxd_pix_out, flt_pix_out                 : out pixel_t;
    fxd_pix_wr_req, flt_pix_wr_req           : out std_logic;
    fusao_pix_wr_burst_en                    : in  std_logic;

    norma_threshold : in std_logic_vector(C_LARGURA_PIXEL+2-1 downto 0);

    offset              : out std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);
    ent_valid, mi_valid : out std_logic;
    ent_data, mi_data   : out std_logic_vector(LARGURA_BINS + LARGURA_ADDR_BINS + 4 +4 + 1-1 downto 0)
    );
end entity registration;

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
architecture fpga of registration is

  constant NUMERO_HISTOGRAMAS   : integer := 2**LARGURA_N_HISTOGRAMAS;
  constant NUMERO_TAMANHO_PASSO : integer := 2**LARGURA_PASSO;
  constant NUMERO_BINS          : integer := 2** LARGURA_ADDR_BINS;
  constant LARGURA_SHIFTS       : integer := LARGURA_N_HISTOGRAMAS + LARGURA_ITERACOES;
  constant NUMERO_SHIFTS        : integer := NUMERO_HISTOGRAMAS*NUMERO_ITERACOES-1;
  constant LARGURA_ENT_MI       : integer := LARGURA_BINS + LARGURA_ADDR_BINS + 4 +4 + 1;

  constant NUMERO_PIXEIS_EXTRAS : integer := (NUMERO_HISTOGRAMAS-1)*NUMERO_TAMANHO_PASSO-1;
  constant BLOCO_ITERACAO       : integer := NUMERO_HISTOGRAMAS*NUMERO_TAMANHO_PASSO;

  constant DELAY_PIPELINE                   : integer   := 4*NUMERO_HISTOGRAMAS+16;
  signal entropia_out, mi_out               : std_logic_vector(LARGURA_ENT_MI-1 downto 0);
  signal entropia_out_valido, mi_out_valido : std_logic := '0';
  type estado_mi_t is (ST_OCIOSO, ST_CALCULA_HISTOGRAMA_PRE_LINHA,
                       ST_CALCULA_HISTOGRAMA_INICIO_LINHA, ST_CALCULA_HISTOGRAMA_MEIO_LINHA,
                       ST_CALCULA_HISTOGRAMA_PIXEL_EXTRA, ST_CALCULA_HISTOGRAMA_POS_LINHA,
                       ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_INICIO, ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_MEIO,
                       ST_ESPERA_PIPELINE, ST_CALCULA_PARAMETROS,
                       ST_CALCULA_OFFSET, ST_LIMPA_BINS, ST_LIMPA_BINS_INICIAL);
  type flop_controle_t is record
    estado                        : estado_mi_t;
    pixel_counter                 : unsigned(LARGURA_CONTADOR_LINHAS+LARGURA_CONTADOR_COLUNAS-1 downto 0);
    line_counter                  : unsigned(LARGURA_CONTADOR_LINHAS-1 downto 0);
    hist_counter                  : unsigned(LARGURA_N_HISTOGRAMAS-1 downto 0);
    it_counter                    : unsigned(LARGURA_ITERACOES-1 downto 0);
    flt_valid_strt, flt_valid_end : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0);

    fxd_inicio_linha                  : std_logic;
    fxd_inicio_linha_adiantado        : std_logic;
    flt_inicio_linha                  : std_logic;
    flt_inicio_linha_adiantado        : std_logic;
    fxd_segundo_pixel_linha           : std_logic;
    fxd_segundo_pixel_linha_adiantado : std_logic;
    flt_segundo_pixel_linha           : std_logic;
    flt_segundo_pixel_linha_adiantado : std_logic;
    flt_fim_linha                     : std_logic;
    flt_fim_linha_adiantado           : std_logic;
    fxd_fim_linha                     : std_logic;
    fxd_fim_linha_adiantado           : std_logic;

    flt_apos_fim_linha           : std_logic;
    flt_apos_fim_linha_adiantado : std_logic;
    fxd_apos_fim_linha           : std_logic;
    fxd_apos_fim_linha_adiantado : std_logic;

    flt_primeira_linha              : std_logic;
    flt_primeira_linha_adiantado    : std_logic;
    flt_segunda_linha               : std_logic;
    flt_segunda_linha_adiantado     : std_logic;
    flt_apos_ultima_linha           : std_logic;
    flt_apos_ultima_linha_adiantado : std_logic;

    fxd_primeira_linha              : std_logic;
    fxd_primeira_linha_adiantado    : std_logic;
    fxd_segunda_linha               : std_logic;
    fxd_segunda_linha_adiantado     : std_logic;
    fxd_apos_ultima_linha           : std_logic;
    fxd_apos_ultima_linha_adiantado : std_logic;

    fim_quadro        : std_logic;
    prox_shift        : std_logic;
    prox_offset       : std_logic;
    terminou_entropia : std_logic;
    terminou_mi       : std_logic;
    limpando_bins     : std_logic;
    flt_pix_rd_req    : std_logic;
    flt_pix_rd_ignore : std_logic;

    flt_pix_in_valid : std_logic;
    fxd_pix_rd_req   : std_logic;
    fxd_pix_in_valid : std_logic;

    offset_limpa_estado : std_logic;
  end record flop_controle_t;
  constant DEF_FLT_VALID_STRT : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0) := to_unsigned((NUMERO_ITERACOES-1)*BLOCO_ITERACAO, LARGURA_CONTADOR_COLUNAS);
  constant DEF_FLT_VALID_END  : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0) := (others => '0');
  constant DEF_FLOP_CONTROLE  : flop_controle_t := (
    estado                            => ST_LIMPA_BINS_INICIAL,
    pixel_counter                     => (others => '0'),
    line_counter                      => (others => '0'),
    hist_counter                      => (others => '0'),
    it_counter                        => (others => '0'),
    flt_valid_strt                    => DEF_FLT_VALID_STRT,
    flt_valid_end                     => DEF_FLT_VALID_END,
    fxd_inicio_linha                  => '0',
    fxd_inicio_linha_adiantado        => '0',
    flt_inicio_linha                  => '0',
    flt_inicio_linha_adiantado        => '0',
    fxd_segundo_pixel_linha           => '0',
    fxd_segundo_pixel_linha_adiantado => '0',
    flt_segundo_pixel_linha           => '0',
    flt_segundo_pixel_linha_adiantado => '0',
    flt_fim_linha                     => '0',
    flt_fim_linha_adiantado           => '0',
    fxd_fim_linha                     => '0',
    fxd_fim_linha_adiantado           => '0',
    flt_apos_fim_linha                => '0',
    flt_apos_fim_linha_adiantado      => '0',
    fxd_apos_fim_linha                => '0',
    fxd_apos_fim_linha_adiantado      => '0',

    flt_primeira_linha              => '0',
    flt_primeira_linha_adiantado    => '0',
    flt_segunda_linha               => '0',
    flt_segunda_linha_adiantado     => '0',
    flt_apos_ultima_linha           => '0',
    flt_apos_ultima_linha_adiantado => '0',

    fxd_primeira_linha              => '0',
    fxd_primeira_linha_adiantado    => '0',
    fxd_segunda_linha               => '0',
    fxd_segunda_linha_adiantado     => '0',
    fxd_apos_ultima_linha           => '0',
    fxd_apos_ultima_linha_adiantado => '0',

    fim_quadro        => '0',
    prox_shift        => '0',
    prox_offset       => '0',
    terminou_entropia => '0',
    terminou_mi       => '0',
    limpando_bins     => '0',
    flt_pix_rd_req    => '0',
    flt_pix_in_valid  => '0',
    flt_pix_rd_ignore => '0',
    fxd_pix_rd_req    => '0',
    fxd_pix_in_valid  => '0',

    offset_limpa_estado => '0');
  signal flop_controle : flop_controle_t := DEF_FLOP_CONTROLE;

  type flop_ent_mi_out_t is record
    ent, mi : std_logic_vector(LARGURA_ENT_MI-1 downto 0);
  end record flop_ent_mi_out_t;
  constant DEF_ENT_MI_OUT : flop_ent_mi_out_t := (
    ent => (others => '0'),
    mi  => (others => '0'));
  signal flop_ent_mi_out : flop_ent_mi_out_t := DEF_ENT_MI_OUT;

  signal terminou_offset : std_logic := '0';

  signal flt_pix_in_reading, fxd_pix_in_reading : std_logic := '0';
  -- purpose: Preenche os sinais de controle do referente a posicao atual
  --          da pixel ativo
  procedure get_controle (
    signal flop_controle_in                           : in  flop_controle_t;
    signal inicio_linha, segundo_pix_linha, fim_linha : out std_logic;
    signal primeira_linha, segunda_linha              : out std_logic;
    constant ESCREVE_INICIO_LINHA                     : in  boolean) is
  begin  -- procedure get_controle

    if(ESCREVE_INICIO_LINHA) then
      if 0 = flop_controle_in.pixel_counter then
        inicio_linha <= '1';
      else
        inicio_linha <= '0';
      end if;

      if 1 = flop_controle_in.pixel_counter then
        segundo_pix_linha <= '1';
      else
        segundo_pix_linha <= '0';
      end if;
    else
      inicio_linha      <= '0';
      segundo_pix_linha <= '0';
    end if;

    if NUMERO_COLUNAS-1 = flop_controle_in.pixel_counter then
      fim_linha <= '1';
    else
      fim_linha <= '0';
    end if;

    if 0 = flop_controle_in.line_counter then
      primeira_linha <= '1';
    else
      primeira_linha <= '0';
    end if;

    if 1 = flop_controle_in.line_counter then
      segunda_linha <= '1';
    else
      segunda_linha <= '0';
    end if;

  end procedure get_controle;

begin  -- architecture fpga
  
  end_frame <= flop_controle.fim_quadro;

  flt_pix_rd_req <= flop_controle.flt_pix_rd_req;
  fxd_pix_rd_req <= flop_controle.fxd_pix_rd_req;
  -- purpose: Implementa a maquina de estados e o datapath
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_controle   <= DEF_FLOP_CONTROLE;
      flop_ent_mi_out <= DEF_ENT_MI_OUT;

      fxd_pix_wr_req     <= '0';
      fxd_pix_out        <= (others => '0');
      fxd_pix_in_reading <= '0';

      flt_pix_wr_req     <= '0';
      flt_pix_out        <= (others => '0');
      flt_pix_in_reading <= '0';
      
    elsif clk'event and clk = '1' then  -- rising clock edge
      fxd_pix_in_reading <= flop_controle.fxd_pix_rd_req;
      fxd_pix_wr_req     <= fxd_pix_in_reading;
      fxd_pix_out        <= fxd_pix_in;

      flt_pix_in_reading <= flop_controle.flt_pix_rd_req;
      flt_pix_wr_req     <= flt_pix_in_reading;
      flt_pix_out        <= flt_pix_in;

      flop_controle.flt_pix_in_valid <= flop_controle.flt_pix_rd_req and
                                        (not flop_controle.flt_pix_rd_ignore);
      flop_controle.fxd_pix_in_valid <= flop_controle.fxd_pix_rd_req;

      -- A leitura fifo adiciona um ciclo de atraso, assim todos os sinais de controle
      -- tem que ser atrasados um ciclo
      flop_controle.flt_inicio_linha        <= flop_controle.flt_inicio_linha_adiantado;
      flop_controle.flt_segundo_pixel_linha <= flop_controle.flt_segundo_pixel_linha_adiantado;
      flop_controle.flt_apos_fim_linha      <= flop_controle.flt_apos_fim_linha_adiantado;
      flop_controle.flt_primeira_linha      <= flop_controle.flt_primeira_linha_adiantado;
      flop_controle.flt_segunda_linha       <= flop_controle.flt_segunda_linha_adiantado;
      flop_controle.flt_apos_ultima_linha   <= flop_controle.flt_apos_ultima_linha_adiantado;
      flop_controle.flt_fim_linha           <= flop_controle.flt_fim_linha_adiantado;


      flop_controle.fxd_inicio_linha        <= flop_controle.fxd_inicio_linha_adiantado;
      flop_controle.fxd_segundo_pixel_linha <= flop_controle.fxd_segundo_pixel_linha_adiantado;
      flop_controle.fxd_apos_fim_linha      <= flop_controle.fxd_apos_fim_linha_adiantado;
      flop_controle.fxd_primeira_linha      <= flop_controle.fxd_primeira_linha_adiantado;
      flop_controle.fxd_segunda_linha       <= flop_controle.fxd_segunda_linha_adiantado;
      flop_controle.fxd_apos_ultima_linha   <= flop_controle.fxd_apos_ultima_linha_adiantado;
      flop_controle.fxd_fim_linha           <= flop_controle.fxd_fim_linha_adiantado;

      flop_controle.flt_pix_rd_req    <= '0';
      flop_controle.flt_pix_rd_ignore <= '0';
      flop_controle.fxd_pix_rd_req    <= '0';

      flop_controle.flt_inicio_linha_adiantado        <= '0';
      flop_controle.flt_segundo_pixel_linha_adiantado <= '0';
      flop_controle.flt_apos_fim_linha_adiantado      <= '0';
      flop_controle.flt_primeira_linha_adiantado      <= '0';
      flop_controle.flt_segunda_linha_adiantado       <= '0';
      flop_controle.flt_apos_ultima_linha_adiantado   <= '0';
      flop_controle.flt_fim_linha_adiantado           <= '0';

      flop_controle.fxd_inicio_linha_adiantado        <= '0';
      flop_controle.fxd_segundo_pixel_linha_adiantado <= '0';
      flop_controle.fxd_apos_fim_linha_adiantado      <= '0';
      flop_controle.fxd_primeira_linha_adiantado      <= '0';
      flop_controle.fxd_segunda_linha_adiantado       <= '0';
      flop_controle.fxd_apos_ultima_linha_adiantado   <= '0';
      flop_controle.fxd_fim_linha_adiantado           <= '0';

      flop_controle.prox_shift  <= '0';
      flop_controle.prox_offset <= '0';
      flop_controle.fim_quadro  <= '0';

      flop_controle.limpando_bins       <= '0';
      flop_controle.offset_limpa_estado <= '0';

      case flop_controle.estado is
        when ST_LIMPA_BINS_INICIAL =>
          flop_controle.pixel_counter <= flop_controle.pixel_counter +1;
          flop_controle.limpando_bins <= '1';

          if NUMERO_BINS*NUMERO_BINS-1 = flop_controle.pixel_counter then
            flop_controle.hist_counter   <= (others => '0');
            flop_controle.pixel_counter  <= (others => '0');
            flop_controle.line_counter   <= (others => '0');
            flop_controle.it_counter     <= (others => '0');
            flop_controle.flt_valid_strt <= DEF_FLT_VALID_STRT;
            flop_controle.flt_valid_end  <= DEF_FLT_VALID_END;

            flop_controle.estado <= ST_OCIOSO;
          end if;
        when ST_OCIOSO =>
          if '1' = start_frame then

            flop_controle.estado        <= ST_CALCULA_HISTOGRAMA_PRE_LINHA;
            flop_controle.hist_counter  <= (others => '0');
            flop_controle.pixel_counter <= (others => '0');
            flop_controle.line_counter  <= (others => '0');
          end if;

        when ST_CALCULA_HISTOGRAMA_PRE_LINHA =>
          -- se essa iteracao nao tiver pixeis a serem jogados fora no inicio
          -- da linha
          -- ou se for a ultima linha
          if flop_controle.flt_valid_strt = 0 then
            flop_controle.pixel_counter <= (others => '0');
            flop_controle.estado        <= ST_CALCULA_HISTOGRAMA_INICIO_LINHA;

          -- le dados para jogar fora
          elsif '1' = flt_pix_rd_burst_en then
            flop_controle.pixel_counter     <= flop_controle.pixel_counter + 1;
            flop_controle.flt_pix_rd_req    <= '1';
            flop_controle.flt_pix_rd_ignore <= '1';
            -- ou se tiver lido o ultimo dado
            if flop_controle.pixel_counter = flop_controle.flt_valid_strt - 1 then
              flop_controle.pixel_counter <= (others => '0');
              flop_controle.estado        <= ST_CALCULA_HISTOGRAMA_INICIO_LINHA;
            end if;
          end if;

        when ST_CALCULA_HISTOGRAMA_INICIO_LINHA =>
          -- le pixels em um a cada NUMERO_HISTOGRAMAS ciclos
          if flop_controle.hist_counter = NUMERO_HISTOGRAMAS-1 then
            -- le os pixels se houver algum na fila
            if '1' = flt_pix_rd_burst_en then
              flop_controle.hist_counter   <= (others => '0');
              flop_controle.flt_pix_rd_req <= '1';

              get_controle(flop_controle, flop_controle.flt_inicio_linha_adiantado,
                           flop_controle.flt_segundo_pixel_linha_adiantado,
                           flop_controle.flt_fim_linha_adiantado,
                           flop_controle.flt_primeira_linha_adiantado,
                           flop_controle.flt_segunda_linha_adiantado, true);


              flop_controle.pixel_counter <= flop_controle.pixel_counter + 1;

              -- fica nesse estado ate terminar de ler os pixels extras da
              -- imagem float
              if NUMERO_PIXEIS_EXTRAS = flop_controle.pixel_counter then
                flop_controle.hist_counter  <= (others => '0');
                flop_controle.pixel_counter <= (others => '0');
                flop_controle.estado        <= ST_CALCULA_HISTOGRAMA_MEIO_LINHA;
              end if;

            end if;

          else
            flop_controle.hist_counter <= flop_controle.hist_counter +1;
          end if;

        when ST_CALCULA_HISTOGRAMA_MEIO_LINHA =>
          if flop_controle.hist_counter = NUMERO_HISTOGRAMAS-1 then
            -- nao le pixels nem na ultima linha nem no ultimo pixel
            -- o sobel utiliza esse tempo para calcular
            if ('1' = flt_pix_rd_burst_en) and
              ('1' = fxd_pix_rd_burst_en) then

              flop_controle.hist_counter   <= (others => '0');
              flop_controle.flt_pix_rd_req <= '1';
              flop_controle.fxd_pix_rd_req <= '1';
              flop_controle.pixel_counter  <= flop_controle.pixel_counter + 1;

              get_controle(flop_controle, flop_controle.flt_inicio_linha_adiantado,
                           flop_controle.flt_segundo_pixel_linha_adiantado,
                           flop_controle.flt_fim_linha_adiantado,
                           flop_controle.flt_primeira_linha_adiantado,
                           flop_controle.flt_segunda_linha_adiantado, false);

              get_controle(flop_controle, flop_controle.fxd_inicio_linha_adiantado,
                           flop_controle.fxd_segundo_pixel_linha_adiantado,
                           flop_controle.fxd_fim_linha_adiantado,
                           flop_controle.fxd_primeira_linha_adiantado,
                           flop_controle.fxd_segunda_linha_adiantado, true);

              if NUMERO_COLUNAS-1 = flop_controle.pixel_counter then
                flop_controle.estado <= ST_CALCULA_HISTOGRAMA_PIXEL_EXTRA;
              end if;
            end if;  -- if que verifica se esta na ultima
            -- linha (ou no ultimo pixel)
            
          else
            flop_controle.hist_counter <= flop_controle.hist_counter +1;
          end if;  -- if que conta o shift

        when ST_CALCULA_HISTOGRAMA_PIXEL_EXTRA =>
          if flop_controle.hist_counter = NUMERO_HISTOGRAMAS-1 then
            
            flop_controle.hist_counter <= (others => '0');
            get_controle(flop_controle, flop_controle.flt_inicio_linha_adiantado,
                         flop_controle.flt_segundo_pixel_linha_adiantado,
                         flop_controle.flt_fim_linha_adiantado,
                         flop_controle.flt_primeira_linha_adiantado,
                         flop_controle.flt_segunda_linha_adiantado, false);

            get_controle(flop_controle, flop_controle.fxd_inicio_linha_adiantado,
                         flop_controle.fxd_segundo_pixel_linha_adiantado,
                         flop_controle.fxd_fim_linha_adiantado,
                         flop_controle.fxd_primeira_linha_adiantado,
                         flop_controle.fxd_segunda_linha_adiantado, true);

            flop_controle.flt_apos_fim_linha_adiantado <= '1';
            flop_controle.fxd_apos_fim_linha_adiantado <= '1';
            -- fim da linha
            flop_controle.estado                       <= ST_CALCULA_HISTOGRAMA_POS_LINHA;
            flop_controle.pixel_counter                <= (others => '0');
          else
            flop_controle.hist_counter <= flop_controle.hist_counter +1;
          end if;
          
        when ST_CALCULA_HISTOGRAMA_POS_LINHA =>
          -- se nao houverem dados para jogar fora
          if 0 = flop_controle.flt_valid_end then
            flop_controle.pixel_counter <= (others => '0');
            flop_controle.line_counter  <= flop_controle.line_counter + 1;
            -- fim do frame ou da linha
            if NUMERO_LINHAS-1 = flop_controle.line_counter then
              flop_controle.estado <= ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_INICIO;
            else
              flop_controle.estado <= ST_CALCULA_HISTOGRAMA_PRE_LINHA;
            end if;
          -- se houver dados para jogar fora
          elsif '1' = flt_pix_rd_burst_en then
            flop_controle.pixel_counter     <= flop_controle.pixel_counter + 1;
            flop_controle.flt_pix_rd_req    <= '1';
            flop_controle.flt_pix_rd_ignore <= '1';
            -- se terminou de jogar os dados fora, move para o proximo estado
            if flop_controle.pixel_counter = flop_controle.flt_valid_end - 1 then
              flop_controle.pixel_counter <= (others => '0');
              flop_controle.line_counter  <= flop_controle.line_counter + 1;
              -- fim do frame ou da linha
              if NUMERO_LINHAS-1 = flop_controle.line_counter then
                flop_controle.estado <= ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_INICIO;
              else
                flop_controle.estado <= ST_CALCULA_HISTOGRAMA_PRE_LINHA;
              end if;
            end if;
          end if;

        when ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_INICIO =>
          -- le pixels em um a cada NUMERO_HISTOGRAMAS ciclos
          if flop_controle.hist_counter = NUMERO_HISTOGRAMAS-1 then
            flop_controle.hist_counter <= (others => '0');
            get_controle(flop_controle, flop_controle.flt_inicio_linha_adiantado,
                         flop_controle.flt_segundo_pixel_linha_adiantado,
                         flop_controle.flt_fim_linha_adiantado,
                         flop_controle.flt_primeira_linha_adiantado,
                         flop_controle.flt_segunda_linha_adiantado, true);


            flop_controle.pixel_counter                   <= flop_controle.pixel_counter + 1;
            flop_controle.flt_apos_ultima_linha_adiantado <= '1';

            -- fica nesse estado ate terminar de ler os pixels extras da
            -- imagem float
            if NUMERO_PIXEIS_EXTRAS = flop_controle.pixel_counter then
              flop_controle.hist_counter  <= (others => '0');
              flop_controle.pixel_counter <= (others => '0');
              flop_controle.estado        <= ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_MEIO;
            end if;

          else
            flop_controle.hist_counter <= flop_controle.hist_counter +1;
          end if;
          
        when ST_CALCULA_HISTOGRAMA_LINHA_EXTRA_MEIO =>
          if flop_controle.hist_counter = NUMERO_HISTOGRAMAS-1 then
            flop_controle.hist_counter <= (others => '0');
            get_controle(flop_controle, flop_controle.flt_inicio_linha_adiantado,
                         flop_controle.flt_segundo_pixel_linha_adiantado,
                         flop_controle.flt_fim_linha_adiantado,
                         flop_controle.flt_primeira_linha_adiantado,
                         flop_controle.flt_segunda_linha_adiantado, false);

            get_controle(flop_controle, flop_controle.fxd_inicio_linha_adiantado,
                         flop_controle.fxd_segundo_pixel_linha_adiantado,
                         flop_controle.fxd_fim_linha_adiantado,
                         flop_controle.fxd_primeira_linha_adiantado,
                         flop_controle.fxd_segunda_linha_adiantado, true);

            flop_controle.pixel_counter <= flop_controle.pixel_counter + 1;

            flop_controle.flt_apos_ultima_linha_adiantado <= '1';
            flop_controle.fxd_apos_ultima_linha_adiantado <= '1';

            -- fim da linha extra
            if NUMERO_COLUNAS = flop_controle.pixel_counter then
              flop_controle.flt_apos_fim_linha_adiantado <= '1';
              flop_controle.fxd_apos_fim_linha_adiantado <= '1';

              flop_controle.pixel_counter <= (others => '0');
              flop_controle.line_counter  <= (others => '0');
              flop_controle.estado        <= ST_ESPERA_PIPELINE;
            end if;
            
          else
            flop_controle.hist_counter <= flop_controle.hist_counter +1;
          end if;
          
        when ST_ESPERA_PIPELINE =>
          flop_controle.pixel_counter <= flop_controle.pixel_counter+1;
          if DELAY_PIPELINE+NUMERO_COLUNAS*NUMERO_HISTOGRAMAS-1 = flop_controle.pixel_counter then
            flop_controle.estado            <= ST_CALCULA_PARAMETROS;
            flop_controle.terminou_mi       <= '0';
            flop_controle.terminou_entropia <= '0';
            flop_controle.prox_shift        <= '1';
            flop_controle.hist_counter      <= (others => '0');
          end if;


        when ST_CALCULA_PARAMETROS =>
          if '1' = entropia_out_valido then
            flop_controle.terminou_entropia <= '1';
          end if;

          if '1' = mi_out_valido then
            flop_controle.terminou_mi <= '1';
          end if;

          if ('1' = flop_controle.terminou_entropia) and ('1' = flop_controle.terminou_mi) then
            flop_controle.prox_offset <= '1';
            flop_controle.estado      <= ST_CALCULA_OFFSET;
          end if;

        when ST_CALCULA_OFFSET =>
          if '1' = terminou_offset then
            flop_controle.hist_counter      <= flop_controle.hist_counter +1;
            flop_controle.estado            <= ST_CALCULA_PARAMETROS;
            flop_controle.terminou_mi       <= '0';
            flop_controle.terminou_entropia <= '0';
            flop_controle.prox_shift        <= '1';
            if NUMERO_HISTOGRAMAS-1 = flop_controle.hist_counter then
              flop_controle.prox_shift    <= '0';
              flop_controle.estado        <= ST_LIMPA_BINS;
              flop_controle.pixel_counter <= (others => '0');
            end if;
          end if;

        when ST_LIMPA_BINS =>
          flop_controle.pixel_counter <= flop_controle.pixel_counter +1;
          flop_controle.limpando_bins <= '1';

          if NUMERO_BINS*NUMERO_BINS-1 = flop_controle.pixel_counter then
            flop_controle.hist_counter  <= (others => '0');
            flop_controle.pixel_counter <= (others => '0');
            -- ultima iteracao do calculo do offset, reseta todos os contadores
            -- e o estado do bloco de calculo de offset
            if flop_controle.it_counter = NUMERO_ITERACOES-1 then
              flop_controle.it_counter          <= (others => '0');
              flop_controle.flt_valid_strt      <= DEF_FLT_VALID_STRT;
              flop_controle.flt_valid_end       <= DEF_FLT_VALID_END;
              flop_controle.offset_limpa_estado <= '1';
              flop_controle.fim_quadro    <= '1';
            else
              flop_controle.it_counter     <= flop_controle.it_counter + 1;
              flop_controle.flt_valid_strt <= flop_controle.flt_valid_strt - BLOCO_ITERACAO;
              flop_controle.flt_valid_end  <= flop_controle.flt_valid_end + BLOCO_ITERACAO;
            end if;
            flop_controle.estado <= ST_OCIOSO;
          end if;
          
        when others => flop_controle <= DEF_FLOP_CONTROLE;
      end case;

      if '1' = entropia_out_valido then
        flop_ent_mi_out.ent <= entropia_out;
        report "log_debug: Registro entropia        it:" &
          integer'image(to_integer(flop_controle.it_counter)) & "   shift:" &
          integer'image(to_integer(flop_controle.hist_counter)) & "   valor:" &
          integer'image(to_integer(signed(entropia_out))) severity note;
      end if;

      if '1' = mi_out_valido then
        flop_ent_mi_out.mi <= mi_out;
        report "log_debug: Registro mi             it:" &
          integer'image(to_integer(flop_controle.it_counter)) & "   shift:" &
          integer'image(to_integer(flop_controle.hist_counter)) & "   valor:" &
          integer'image(to_integer(signed(mi_out))) severity note;
      end if;

    end if;
  end process clk_proc;

  entropia_1 : entity work.entropia
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS,
      NUMERO_LINHAS            => NUMERO_LINHAS,
      LARGURA_CONTADOR_LINHAS  => LARGURA_CONTADOR_LINHAS,
      LARGURA_N_HISTOGRAMAS    => LARGURA_N_HISTOGRAMAS,
      LARGURA_PASSO            => LARGURA_PASSO,
      LARGURA_BINS             => LARGURA_BINS,
      LARGURA_ADDR_BINS        => LARGURA_ADDR_BINS,
      LARGURA_ENTROPIA_OUT     => LARGURA_ENT_MI,
      DEBUG                    => DEBUG
      )
    port map (
      clk           => clk,
      rst_n         => rst_n,
      fxd_pix_in    => fxd_pix_in,
      flt_pix_in    => flt_pix_in,
      fxd_pix_valid => flop_controle.fxd_pix_in_valid,
      flt_pix_valid => flop_controle.flt_pix_in_valid,

      flt_inicio_linha_in        => flop_controle.flt_inicio_linha,
      fxd_inicio_linha_in        => flop_controle.fxd_inicio_linha,
      flt_segundo_pixel_linha_in => flop_controle.flt_segundo_pixel_linha,
      fxd_segundo_pixel_linha_in => flop_controle.fxd_segundo_pixel_linha,
      flt_apos_fim_linha_in      => flop_controle.flt_apos_fim_linha,
      fxd_apos_fim_linha_in      => flop_controle.fxd_apos_fim_linha,
      flt_primeira_linha_in      => flop_controle.flt_primeira_linha,
      fxd_primeira_linha_in      => flop_controle.fxd_primeira_linha,
      flt_segunda_linha_in       => flop_controle.flt_segunda_linha,
      fxd_segunda_linha_in       => flop_controle.fxd_segunda_linha,
      flt_apos_ultima_linha_in   => flop_controle.flt_apos_ultima_linha,
      fxd_apos_ultima_linha_in   => flop_controle.fxd_apos_ultima_linha,

      norma_threshold     => norma_threshold,
      limpa_bins          => flop_controle.limpando_bins,
      entropia_prox_shift => flop_controle.prox_shift,
      entropia_out_valido => entropia_out_valido,
      entropia_out        => entropia_out
      );
  ent_data <= entropia_out;
  ent_valid <= entropia_out_valido;
  
  mutual_information_1 : entity work.mutual_information
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS,
      NUMERO_LINHAS            => NUMERO_LINHAS,
      LARGURA_CONTADOR_LINHAS  => LARGURA_CONTADOR_LINHAS,
      LARGURA_N_HISTOGRAMAS    => LARGURA_N_HISTOGRAMAS,
      LARGURA_PASSO            => LARGURA_PASSO,
      LARGURA_BINS             => LARGURA_BINS,
      LARGURA_ADDR_BINS        => LARGURA_ADDR_BINS,
      LARGURA_MI_OUT           => LARGURA_ENT_MI,
      LARGURA_N_PIXELS         => LARGURA_N_PIXELS,
      DEBUG                    => DEBUG
      )
    port map (
      clk           => clk,
      rst_n         => rst_n,
      fxd_pix_in    => fxd_pix_in,
      flt_pix_in    => flt_pix_in,
      fxd_pix_valid => flop_controle.fxd_pix_in_valid,
      flt_pix_valid => flop_controle.flt_pix_in_valid,

      fxd_inicio_linha   => flop_controle.fxd_inicio_linha,
      flt_inicio_linha   => flop_controle.flt_inicio_linha,
      fxd_apos_fim_linha => flop_controle.fxd_apos_fim_linha,
      flt_apos_fim_linha => flop_controle.flt_apos_fim_linha,

      limpa_bins    => flop_controle.limpando_bins,
      mi_prox_shift => flop_controle.prox_shift,
      mi_out_valido => mi_out_valido,
      mi_out        => mi_out
      );
  mi_data <= mi_out;
  mi_valid <= mi_out_valido;
  
  calcula_offset_1 : entity work.calcula_offset
    generic map (
      LARGURA_BINS             => LARGURA_BINS,
      NUMERO_SHIFTS            => NUMERO_SHIFTS,
      LARGURA_SHIFTS           => LARGURA_SHIFTS,
      LARGURA_PASSO            => LARGURA_PASSO,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS,
      LARGURA_ENTRADAS         => LARGURA_ENT_MI
      )
    port map (
      clk            => clk,
      rst_n          => rst_n,
      entropia_in    => (others => '0'), --flop_ent_mi_out.ent,
      mi_in          => flop_ent_mi_out.mi,
      comeca_calculo => flop_controle.prox_offset,
      fim_calculo    => terminou_offset,
      limpa_estado   => flop_controle.offset_limpa_estado,
      offset_out     => offset,
      escolhe_metodo => escolhe_metodo
      );

end architecture fpga;

