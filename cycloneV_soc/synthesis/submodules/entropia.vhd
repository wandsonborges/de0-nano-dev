-------------------------------------------------------------------------------
-- Title      : entropia
-- Project    : 
-------------------------------------------------------------------------------
-- File       : entropia.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-20
-- Last update: 2017-10-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o calculo da entropia, que consiste em:
--              1- calculo do gradiente das duas, utilizando um filtro sobel
--              2- calculo da diferenca de angulo do gradiente das duas imagens
--              utilizando um coseno
--              3- Constroi um histograma da diferenca dos angulos para cada
--              posicao da imagem flutuante.
--              4- faz a integral da entropia, utilizando valores dos histogramas
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-20  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;


entity entropia is
  
  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    NUMERO_LINHAS            : integer := 256;
    LARGURA_CONTADOR_LINHAS  : integer := 9;
    LARGURA_N_HISTOGRAMAS    : integer := 5;
    LARGURA_PASSO            : integer := 2;
    LARGURA_BINS             : integer := 16;
    LARGURA_ADDR_BINS        : integer := 4;
    LARGURA_ENTROPIA_OUT     : integer := 27;
    NUMERO_ITER_CORDIC       : integer := 12;
    DEBUG                    : boolean := false);

  port (
    clk, rst_n                               : in  std_logic;
    norma_threshold                          : in  std_logic_vector(C_LARGURA_PIXEL+2-1 downto 0);
    fxd_pix_in, flt_pix_in                   : in  pixel_t;
    fxd_pix_valid, flt_pix_valid             : in  std_logic;
    flt_inicio_linha_in, fxd_inicio_linha_in : in  std_logic;
    flt_segundo_pixel_linha_in               : in  std_logic;
    fxd_segundo_pixel_linha_in               : in  std_logic;
    flt_apos_fim_linha_in                    : in  std_logic;
    fxd_apos_fim_linha_in                    : in  std_logic;
    flt_primeira_linha_in                    : in  std_logic;
    fxd_primeira_linha_in                    : in  std_logic;
    flt_segunda_linha_in                     : in  std_logic;
    fxd_segunda_linha_in                     : in  std_logic;
    flt_apos_ultima_linha_in                 : in  std_logic;
    fxd_apos_ultima_linha_in                 : in  std_logic;
    limpa_bins                               : in  std_logic;
    entropia_prox_shift                      : in  std_logic;
    entropia_out_valido                      : out std_logic;
    entropia_out                             : out std_logic_vector(LARGURA_ENTROPIA_OUT-1 downto 0));

end entity entropia;

architecture fpga of entropia is

  constant NUMERO_HISTOGRAMAS : integer := 2**LARGURA_N_HISTOGRAMAS;
  constant PASSO_SHIFTS       : integer := 2**LARGURA_PASSO;
  constant NUMERO_BINS        : integer := 2** LARGURA_ADDR_BINS;
  constant LARGURA_SOBEL_OUT  : integer := C_LARGURA_PIXEL+3;

  signal flt_dx_out, flt_dy_out : std_logic_vector(LARGURA_SOBEL_OUT-1 downto 0);
  signal fxd_dx_out, fxd_dy_out : std_logic_vector(LARGURA_SOBEL_OUT-1 downto 0);

  signal flt_sobel_valido_out, fxd_sobel_valido_out     : std_logic;
  signal flt_sobel_inicio_linha, fxd_sobel_inicio_linha : std_logic;
  signal flt_sobel_fim_linha, fxd_sobel_fim_linha       : std_logic;

  subtype sobel_out_t is std_logic_vector(LARGURA_SOBEL_OUT-1 downto 0);

  type estado_sobel_out_t is (ST_OCIOSO, ST_ENCHENDO_BUFFER, ST_GRAVANDO_BUFFER, ST_LENDO_BUFFER);
  type flop_sobel_out_t is record
    estado             : estado_sobel_out_t;
    ultimo_pixel_linha : std_logic;
    usa_buffer         : std_logic;
    fxd_dx, fxd_dy     : sobel_out_t;
    fxd_dx_i, fxd_dy_i : sobel_out_t;
    flt_dx, flt_dy     : sobel_out_t;
    ang_in_valido      : std_logic;
    cb_rd_wr_n         : std_logic;
    cb_data_in         : std_logic_vector(2*(LARGURA_SOBEL_OUT)-1 downto 0);
    cb_rd_addr         : std_logic_vector(LARGURA_N_HISTOGRAMAS+LARGURA_PASSO-1 downto 0);
  end record flop_sobel_out_t;
  constant DEF_FLOP_SOBEL_OUT : flop_sobel_out_t := (
    estado             => ST_OCIOSO,
    ultimo_pixel_linha => '0',
    usa_buffer         => '0',
    fxd_dx             => (others => '0'),
    fxd_dy             => (others => '0'),
    fxd_dx_i           => (others => '0'),
    fxd_dy_i           => (others => '0'),
    flt_dx             => (others => '0'),
    flt_dy             => (others => '0'),
    ang_in_valido      => '0',
    cb_data_in         => (others => '0'),
    cb_rd_wr_n         => '1',
    cb_rd_addr         => (others => '0'));
  signal flop_sobel_out           : flop_sobel_out_t := DEF_FLOP_SOBEL_OUT;
  signal flt_dx_diff, flt_dy_diff : sobel_out_t;
  signal fxd_dx_diff, fxd_dy_diff : sobel_out_t;

  signal cb_data_out : std_logic_vector(2*(LARGURA_SOBEL_OUT)-1 downto 0);

  type flop_ang_diff_out_t is record
    ang_count         : std_logic;
    curr_bank_one_hot : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    valido            : std_logic;
    clear_bin         : std_logic;
    ang_bin           : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  end record flop_ang_diff_out_t;
  constant MAX_BANK_SL_ONE_HOT : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0) := (
    NUMERO_HISTOGRAMAS-1 => '1', others => '0');
  constant MIN_BANK_SL_ONE_HOT : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0) := (
    0 => '1', others => '0');
  constant DEF_FLOP_ANG_DIFF_OUT : flop_ang_diff_out_t := (
    ang_count         => '0',
    curr_bank_one_hot => MAX_BANK_SL_ONE_HOT,
    valido            => '0',
    clear_bin         => '0',
    ang_bin           => (others => '0'));
  signal flop_ang_diff_out : flop_ang_diff_out_t := DEF_FLOP_ANG_DIFF_OUT;

  signal ang_diff_out        : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal ang_diff_count      : std_logic;
  signal ang_diff_valido_out : std_logic;

  signal ent_hist_bin_addr      : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal ent_hist_qt            : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal ent_hist_shift_one_hot : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
  signal ent_total_angulos      : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal ent_hist_rd_en         : std_logic;
begin  -- architecture fpga

  -- purpose: Implementa o pipeline da entropia
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_sobel_out    <= DEF_FLOP_SOBEL_OUT;
      flop_ang_diff_out <= DEF_FLOP_ANG_DIFF_OUT;
    elsif clk'event and clk = '1' then  -- rising clock edge

      -- apos a requisicao, marca o pixel como valido
      flop_sobel_out.cb_rd_wr_n    <= '1';
      flop_sobel_out.ang_in_valido <= '0';

      flop_sobel_out.usa_buffer <= '0';

      case flop_sobel_out.estado is
        when ST_OCIOSO =>
          if '1' = flt_sobel_valido_out then
            flop_sobel_out.estado             <= ST_ENCHENDO_BUFFER;
            flop_sobel_out.ultimo_pixel_linha <= '0';
            -- manda gravar
            flop_sobel_out.cb_rd_wr_n         <= '0';
            flop_sobel_out.cb_data_in         <= flt_dx_out & flt_dy_out;
          end if;
          
        when ST_ENCHENDO_BUFFER =>
          if '1' = flt_sobel_valido_out then
            -- manda gravar
            flop_sobel_out.cb_rd_wr_n <= '0';
            flop_sobel_out.cb_data_in <= flt_dx_out & flt_dy_out;
          end if;

          -- encheu o buffer circular, comeca a ler dados de ambas as imagens
          if fxd_sobel_inicio_linha = '1' then
            flop_sobel_out.estado     <= ST_GRAVANDO_BUFFER;
            -- flop entradas geradas
            flop_sobel_out.fxd_dx_i   <= fxd_dx_out;
            flop_sobel_out.fxd_dy_i   <= fxd_dy_out;
            flop_sobel_out.flt_dx     <= flt_dx_out;
            flop_sobel_out.flt_dy     <= flt_dy_out;
            -- manda gravar
            flop_sobel_out.cb_rd_wr_n <= '0';
            flop_sobel_out.cb_data_in <= flt_dx_out & flt_dy_out;
          end if;

        when ST_GRAVANDO_BUFFER =>
          flop_sobel_out.estado        <= ST_LENDO_BUFFER;
          flop_sobel_out.usa_buffer    <= '0';
          flop_sobel_out.ang_in_valido <= '1';
          -- le o valor do sobel e grava no buffer
          flop_sobel_out.fxd_dx        <= flop_sobel_out.fxd_dx_i;
          flop_sobel_out.fxd_dy        <= flop_sobel_out.fxd_dy_i;
          -- inicializa o endereco
          flop_sobel_out.cb_rd_addr <= std_logic_vector(
            to_unsigned(PASSO_SHIFTS, LARGURA_N_HISTOGRAMAS+LARGURA_PASSO));

        when ST_LENDO_BUFFER =>
          flop_sobel_out.usa_buffer    <= '1';
          flop_sobel_out.ang_in_valido <= '1';
          -- atualiza o endereco
          flop_sobel_out.cb_rd_addr <= std_logic_vector(unsigned(flop_sobel_out.cb_rd_addr) +
                                                        PASSO_SHIFTS);

          -- ultimo pixel da linha
          if '1' = fxd_sobel_fim_linha then
            flop_sobel_out.ultimo_pixel_linha <= '1';
          end if;

          -- ultimo pixel da linha
          if '1' = flop_sobel_out.ultimo_pixel_linha and
            (NUMERO_HISTOGRAMAS-1)*PASSO_SHIFTS = unsigned(flop_sobel_out.cb_rd_addr) then
            flop_sobel_out.estado <= ST_OCIOSO;
          -- ultimo ciclo da leitura le o pixel e manda gravar no buffer
          elsif (NUMERO_HISTOGRAMAS-1)*PASSO_SHIFTS = unsigned(flop_sobel_out.cb_rd_addr) then
            if('1' = fxd_sobel_valido_out) and ('1' = flt_sobel_valido_out) then
              flop_sobel_out.cb_rd_addr <= (others => '0');

              flop_sobel_out.estado     <= ST_GRAVANDO_BUFFER;
              -- flop entradas geradas
              flop_sobel_out.fxd_dx_i   <= fxd_dx_out;
              flop_sobel_out.fxd_dy_i   <= fxd_dy_out;
              flop_sobel_out.flt_dx     <= flt_dx_out;
              flop_sobel_out.flt_dy     <= flt_dy_out;
              -- manda gravar
              flop_sobel_out.cb_rd_wr_n <= '0';
              flop_sobel_out.cb_data_in <= flt_dx_out & flt_dy_out;
            else
              assert '0' = flt_sobel_valido_out report "Registration state machine sent a flt pixel while entropy was using buffer data" severity error;
              assert '0' = fxd_sobel_valido_out report "Registration state machine sent a fxd pixel while entropy was using buffer data" severity error;
              -- nao atualiza o endereco nem marca pixel como invalido.
              -- espera um pixel valido
              flop_sobel_out.usa_buffer    <= '0';
              flop_sobel_out.ang_in_valido <= '0';
              flop_sobel_out.cb_rd_addr    <= flop_sobel_out.cb_rd_addr;
            end if;
          else
            assert '0' = flt_sobel_valido_out report "Registration state machine sent a flt pixel while entropy was using buffer data" severity error;
            assert '0' = fxd_sobel_valido_out report "Registration state machine sent a fxd pixel while entropy was using buffer data" severity error;
            
          end if;

          
        when others => null;
      end case;

      flop_ang_diff_out.clear_bin <= '0';
      flop_ang_diff_out.valido    <= ang_diff_valido_out;
      if '1' = ang_diff_valido_out then
        flop_ang_diff_out.ang_count <= ang_diff_count;
        flop_ang_diff_out.ang_bin   <= ang_diff_out;
        flop_ang_diff_out.curr_bank_one_hot <=
          std_logic_vector(rotate_left(unsigned(flop_ang_diff_out.curr_bank_one_hot), 1));
      elsif '1' = limpa_bins then
        flop_ang_diff_out.clear_bin <= '1';
        flop_ang_diff_out.ang_bin   <= std_logic_vector(unsigned(flop_ang_diff_out.ang_bin) + 1);
      end if;

    end if;
  end process clk_proc;

  sobel_fxd : entity work.sobel
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS,
      LARGURA_PIXEL            => C_LARGURA_PIXEL)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      pixel_in               => fxd_pix_in,
      valido_in              => fxd_pix_valid,
      inicio_linha_in        => fxd_inicio_linha_in,
      segundo_pixel_linha_in => fxd_segundo_pixel_linha_in,
      apos_fim_linha_in      => fxd_apos_fim_linha_in,
      primeira_linha_in      => fxd_primeira_linha_in,
      segunda_linha_in       => fxd_segunda_linha_in,
      apos_ultima_linha_in   => fxd_apos_ultima_linha_in,
      valido_out             => fxd_sobel_valido_out,
      inicio_linha_out       => fxd_sobel_inicio_linha,
      fim_linha_out          => fxd_sobel_fim_linha,
      dx_out                 => fxd_dx_out,
      dy_out                 => fxd_dy_out);

  sobel_flt : entity work.sobel
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS + (NUMERO_HISTOGRAMAS-1)*PASSO_SHIFTS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS +1,
      LARGURA_PIXEL            => C_LARGURA_PIXEL)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      pixel_in               => flt_pix_in,
      valido_in              => flt_pix_valid,
      inicio_linha_in        => flt_inicio_linha_in,
      segundo_pixel_linha_in => flt_segundo_pixel_linha_in,
      apos_fim_linha_in      => flt_apos_fim_linha_in,
      primeira_linha_in      => flt_primeira_linha_in,
      segunda_linha_in       => flt_segunda_linha_in,
      apos_ultima_linha_in   => flt_apos_ultima_linha_in,
      valido_out             => flt_sobel_valido_out,
      inicio_linha_out       => flt_sobel_inicio_linha,
      fim_linha_out          => flt_sobel_fim_linha,
      dx_out                 => flt_dx_out,
      dy_out                 => flt_dy_out);

  circular_buffer_1 : entity work.circular_buffer
    generic map (
      NUMERO_WORDS => NUMERO_HISTOGRAMAS*PASSO_SHIFTS,
      LARGURA_ADDR => LARGURA_N_HISTOGRAMAS+LARGURA_PASSO,
      LARGURA_WORD => 2*(LARGURA_SOBEL_OUT))
    port map (
      clk      => clk,
      rst_n    => rst_n,
      rd_addr  => flop_sobel_out.cb_rd_addr,
      data_out => cb_data_out,
      rd_wr_n  => flop_sobel_out.cb_rd_wr_n,
      data_in  => flop_sobel_out.cb_data_in);

  flt_dx_diff <= flop_sobel_out.flt_dx when '0' = flop_sobel_out.usa_buffer else
                 cb_data_out(2*(LARGURA_SOBEL_OUT)-1 downto LARGURA_SOBEL_OUT);
  flt_dy_diff <= flop_sobel_out.flt_dy when '0' = flop_sobel_out.usa_buffer else
                 cb_data_out(LARGURA_SOBEL_OUT-1 downto 0);

  fxd_dx_diff <= flop_sobel_out.fxd_dx;
  fxd_dy_diff <= flop_sobel_out.fxd_dy;

  ent_diff_1 : entity work.ent_diff
    generic map (
      LARGURA_PIXEL => C_LARGURA_PIXEL,
      LARGURA_SAIDA => LARGURA_ADDR_BINS)
    port map (
      clk        => clk,
      rst_n      => rst_n,
      valido_in  => flop_sobel_out.ang_in_valido,
      ang_count  => ang_diff_count,
      valido_out => ang_diff_valido_out,

      img1_dx => fxd_dx_diff,
      img2_dx => flt_dx_diff,
      img1_dy => fxd_dy_diff,
      img2_dy => flt_dy_diff,

      norma_threshold => norma_threshold,
      diff_out        => ang_diff_out);


  histograma_entropia_1 : entity work.histograma_entropia
    generic map (
      NUMERO_BINS        => NUMERO_BINS,
      LARGURA_ADDR_BINS  => LARGURA_ADDR_BINS,
      LARGURA_BINS       => LARGURA_BINS,
      NUMERO_HISTOGRAMAS => NUMERO_HISTOGRAMAS)
    port map (
      clk                => clk,
      rst_n              => rst_n,
      wr_bank_sl_one_hot => flop_ang_diff_out.curr_bank_one_hot,
      valor_in           => flop_ang_diff_out.ang_bin,
      ang_count_in       => flop_ang_diff_out.ang_count,
      valido_in          => flop_ang_diff_out.valido,
      clear_bin          => flop_ang_diff_out.clear_bin,
      rd_en              => ent_hist_rd_en,
      rd_addr            => ent_hist_bin_addr,
      rd_bin_out         => ent_hist_qt,
      rd_total_out       => ent_total_angulos,
      rd_bank_sl_one_hot => ent_hist_shift_one_hot);

  calc_entropia_1 : entity work.calc_entropia
    generic map (
      NUMERO_BINS           => NUMERO_BINS,
      LARGURA_ADDR_BINS     => LARGURA_ADDR_BINS,
      NUMERO_HISTOGRAMAS    => NUMERO_HISTOGRAMAS,
      LARGURA_N_HISTOGRAMAS => LARGURA_N_HISTOGRAMAS,
      LARGURA_BINS          => LARGURA_BINS,
      LARGURA_ENTROPIA_OUT  => LARGURA_ENTROPIA_OUT)
    port map (
      clk                => clk,
      rst_n              => rst_n,
      hist_bin_addr      => ent_hist_bin_addr,
      hist_qt            => ent_hist_qt,
      hist_shift_one_hot => ent_hist_shift_one_hot,
      hist_rd_en         => ent_hist_rd_en,
      total_angulos      => ent_total_angulos,
      prox_shift         => entropia_prox_shift,
      curr_mi_out        => entropia_out,
      curr_mi_out_valido => entropia_out_valido);

      -- entropia_out <= std_logic_vector(resize(signed(flt_dx_out), LARGURA_ENTROPIA_OUT) +
      --                                         resize(signed(flt_dy_out), LARGURA_ENTROPIA_OUT));
      -- entropia_out_valido <= flop_sobel_out.ang_in_valido;

end architecture fpga;
