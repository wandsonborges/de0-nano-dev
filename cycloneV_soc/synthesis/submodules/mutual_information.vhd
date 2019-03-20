-------------------------------------------------------------------------------
-- Title      : mutual_information
-- Project    : 
-------------------------------------------------------------------------------
-- File       : mutual_information.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-12-04
-- Last update: 2014-08-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o mutual information adicionando o controle necessario
--              para construir o histograma e calcular o valor
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-12-04  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity mutual_information is

  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    NUMERO_LINHAS            : integer := 256;
    LARGURA_CONTADOR_LINHAS  : integer := 9;
    LARGURA_N_PIXELS         : integer := 17;
    LARGURA_N_HISTOGRAMAS    : integer := 5;
    LARGURA_PASSO            : integer := 2;
    LARGURA_BINS             : integer := 16;
    LARGURA_ADDR_BINS        : integer := 4;
    LARGURA_MI_OUT           : integer := 27;
    DEBUG                    : boolean := false);

  port (
    clk, rst_n                             : in  std_logic;
    fxd_pix_in, flt_pix_in                 : in  pixel_t;
    fxd_pix_valid, flt_pix_valid           : in  std_logic;
    fxd_inicio_linha, flt_inicio_linha     : in  std_logic;
    fxd_apos_fim_linha, flt_apos_fim_linha : in  std_logic;
    limpa_bins                             : in  std_logic;
    mi_prox_shift                          : in  std_logic;
    mi_out_valido                          : out std_logic;
    mi_out                                 : out std_logic_vector(LARGURA_MI_OUT-1 downto 0));

end entity mutual_information;

architecture fpga of mutual_information is

  constant NUMERO_HISTOGRAMAS : integer := 2**LARGURA_N_HISTOGRAMAS;
  constant PASSO_SHIFTS       : integer := 2**LARGURA_PASSO;
  constant NUMERO_BINS        : integer := 2**LARGURA_ADDR_BINS;

  type estado_buffer_in_t is (ST_OCIOSO, ST_ENCHENDO_BUFFER, ST_GRAVANDO_BUFFER, ST_LENDO_BUFFER);
  type flop_buffer_in_t is record
    estado             : estado_buffer_in_t;
    usa_buffer         : std_logic;
    wr_bank_sl_one_hot : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    fxd_bin_addr       : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    fxd_bin_addr_i     : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    flt_bin_addr       : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    fxd_in_valido      : std_logic;
    flt_in_valido      : std_logic;
    cb_rd_wr_n         : std_logic;
    cb_data_in         : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    cb_rd_addr         : std_logic_vector(LARGURA_N_HISTOGRAMAS+LARGURA_PASSO-1 downto 0);
  end record flop_buffer_in_t;
  constant MAX_BANK_SL_ONE_HOT : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0) := (
    NUMERO_HISTOGRAMAS-1 => '1', others => '0');
  constant MIN_BANK_SL_ONE_HOT : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0) := (
    0 => '1', others => '0');

  constant DEF_FLOP_BUFFER_IN : flop_buffer_in_t := (
    estado             => ST_OCIOSO,
    usa_buffer         => '0',
    wr_bank_sl_one_hot => MIN_BANK_SL_ONE_HOT,
    fxd_bin_addr       => (others => '0'),
    fxd_bin_addr_i     => (others => '0'),
    flt_bin_addr       => (others => '0'),
    fxd_in_valido      => '0',
    flt_in_valido      => '0',
    cb_data_in         => (others => '0'),
    cb_rd_wr_n         => '1',
    cb_rd_addr         => (others => '0'));
  signal flop_buffer_in : flop_buffer_in_t := DEF_FLOP_BUFFER_IN;

  type flop_hist_in_t is record
    wr_bank_sl_one_hot : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    fxd_bin_addr       : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    flt_bin_addr       : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    fxd_in_valido      : std_logic;
    flt_in_valido      : std_logic;
  end record flop_hist_in_t;
  constant DEF_FLOP_HIST_IN : flop_hist_in_t := (
    wr_bank_sl_one_hot => (others => '0'),
    fxd_bin_addr       => (others => '0'),
    flt_bin_addr       => (others => '0'),
    fxd_in_valido      => '0',
    flt_in_valido      => '0');
  signal flop_hist_in : flop_hist_in_t := DEF_FLOP_HIST_IN;


  signal cb_data_out          : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal hist_bin_addr_flt_in : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);


  signal hist_fxd_bin_addr  : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal hist_flt_bin_addr  : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal hist_fxd_qt        : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal hist_flt_qt        : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal hist_h2d_qt        : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal hist_shift_one_hot : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);

  signal hist_valido_fxd_in, hist_valido_flt_in : std_logic;

  signal hist_rd_en         : std_logic;
  signal prox_shift         : std_logic;
  signal curr_mi_out        : std_logic_vector(LARGURA_MI_OUT-1 downto 0);
  signal curr_mi_out_valido : std_logic;

  signal limpa_bins_i : std_logic := '0';
begin  -- architecture fpga

  -- purpose: Implementa o pipeline da mutual information
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_buffer_in <= DEF_FLOP_BUFFER_IN;
    elsif clk'event and clk = '1' then  -- rising clock edge
      limpa_bins_i <= limpa_bins;
      
      -- apos a requisicao, marca o pixel como valido
      flop_buffer_in.cb_rd_wr_n    <= '1';
      flop_buffer_in.flt_in_valido <= '0';
      flop_buffer_in.fxd_in_valido <= '0';
      flop_buffer_in.usa_buffer    <= '0';


      case flop_buffer_in.estado is
        when ST_OCIOSO =>
          -- garante que limpara todas as bins
          if '1' = limpa_bins then
            flop_buffer_in.flt_bin_addr
              <= std_logic_vector(unsigned(flop_buffer_in.flt_bin_addr) + 1);
            if NUMERO_BINS-1 = unsigned(flop_buffer_in.flt_bin_addr) then
              flop_buffer_in.fxd_bin_addr
                <= std_logic_vector(unsigned(flop_buffer_in.fxd_bin_addr) + 1);
              flop_buffer_in.flt_bin_addr <= (others => '0');
            end if;
          else
            flop_buffer_in.flt_bin_addr <= (others => '0');
            flop_buffer_in.fxd_bin_addr <= (others => '0');
          end if;

          if '1' = flt_pix_valid then
            flop_buffer_in.estado     <= ST_ENCHENDO_BUFFER;
            -- manda gravar
            flop_buffer_in.cb_rd_wr_n <= '0';
            flop_buffer_in.cb_data_in
              <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
          end if;

        when ST_ENCHENDO_BUFFER =>
          
          if '1' = flt_pix_valid then
            -- manda gravar
            flop_buffer_in.cb_rd_wr_n <= '0';
            flop_buffer_in.cb_data_in
              <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
          end if;

          if '1' = fxd_inicio_linha then
            flop_buffer_in.estado <= ST_GRAVANDO_BUFFER;
            -- flop entradas geradas
            flop_buffer_in.fxd_bin_addr_i
              <= fxd_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
            flop_buffer_in.flt_bin_addr
              <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
            -- manda gravar
            flop_buffer_in.cb_rd_wr_n <= '0';
            flop_buffer_in.cb_data_in
              <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
          end if;

          
        when ST_GRAVANDO_BUFFER =>

          flop_buffer_in.estado        <= ST_LENDO_BUFFER;
          flop_buffer_in.usa_buffer    <= '0';
          flop_buffer_in.flt_in_valido <= '1';
          flop_buffer_in.fxd_in_valido <= '1';

          -- inicializa o contador
          flop_buffer_in.wr_bank_sl_one_hot <= MIN_BANK_SL_ONE_HOT;
          -- atualiza o valor do fixo do fixo
          flop_buffer_in.fxd_bin_addr       <= flop_buffer_in.fxd_bin_addr_i;
          -- inicializa o endereco
          flop_buffer_in.cb_rd_addr <= std_logic_vector(
            to_unsigned(PASSO_SHIFTS, LARGURA_N_HISTOGRAMAS+LARGURA_PASSO));

        when ST_LENDO_BUFFER =>
          
          flop_buffer_in.usa_buffer <= '1';

          flop_buffer_in.flt_in_valido <= '1';
          flop_buffer_in.wr_bank_sl_one_hot
            <= std_logic_vector(rotate_left(unsigned(flop_buffer_in.wr_bank_sl_one_hot), 1));

          -- atualiza o endereco
          flop_buffer_in.cb_rd_addr <= std_logic_vector(unsigned(flop_buffer_in.cb_rd_addr) +
                                                        PASSO_SHIFTS);

          -- ultimo ciclo da leitura - se for o fim da linha volta para ocioso
          if '1' = fxd_apos_fim_linha then
            flop_buffer_in.estado <= ST_OCIOSO;
          -- se for o ultimo shift, volta a gravar o buffer
          elsif unsigned(flop_buffer_in.cb_rd_addr) = (NUMERO_HISTOGRAMAS-1)*PASSO_SHIFTS then
            if ('1' = fxd_pix_valid) and ('1' = flt_pix_valid) then

              flop_buffer_in.cb_rd_addr <= (others => '0');
              flop_buffer_in.estado     <= ST_GRAVANDO_BUFFER;
              -- flop entradas geradas
              flop_buffer_in.fxd_bin_addr_i
                <= fxd_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
              
              flop_buffer_in.flt_bin_addr
                <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);

              -- manda gravar
              flop_buffer_in.cb_rd_wr_n <= '0';
              flop_buffer_in.cb_data_in
                <= flt_pix_in(C_LARGURA_PIXEL-1 downto C_LARGURA_PIXEL-LARGURA_ADDR_BINS);
            else
              assert '0' = flt_pix_valid report "Registration state machine sent a flt pixel while entropy was using buffer data" severity error;
              assert '0' = fxd_pix_valid report "Registration state machine sent a fxd pixel while entropy was using buffer data" severity error;
              flop_buffer_in.usa_buffer         <= '0';
              flop_buffer_in.flt_in_valido      <= '0';
              flop_buffer_in.cb_rd_addr         <= flop_buffer_in.cb_rd_addr;
              flop_buffer_in.wr_bank_sl_one_hot <= flop_buffer_in.wr_bank_sl_one_hot;
            end if;
          else
            assert '0' = flt_pix_valid report "Registration state machine sent a flt pixel while entropy was using buffer data" severity error;
            assert '0' = fxd_pix_valid report "Registration state machine sent a fxd pixel while entropy was using buffer data" severity error;
          end if;
          
        when others => null;
      end case;

      flop_hist_in.flt_in_valido      <= flop_buffer_in.flt_in_valido;
      flop_hist_in.fxd_in_valido      <= flop_buffer_in.fxd_in_valido;
      flop_hist_in.wr_bank_sl_one_hot <= flop_buffer_in.wr_bank_sl_one_hot;
      flop_hist_in.fxd_bin_addr       <= flop_buffer_in.fxd_bin_addr;
      if flop_buffer_in.usa_buffer = '1' then
        flop_hist_in.flt_bin_addr <= cb_data_out;
      else
        flop_hist_in.flt_bin_addr <= flop_buffer_in.flt_bin_addr;
      end if;
    end if;
  end process clk_proc;

  circular_buffer_1 : entity work.circular_buffer
    generic map (
      NUMERO_WORDS => NUMERO_HISTOGRAMAS*PASSO_SHIFTS,
      LARGURA_ADDR => LARGURA_N_HISTOGRAMAS+LARGURA_PASSO,
      LARGURA_WORD => LARGURA_ADDR_BINS)
    port map (
      clk      => clk,
      rst_n    => rst_n,
      rd_addr  => flop_buffer_in.cb_rd_addr,
      data_out => cb_data_out,
      rd_wr_n  => flop_buffer_in.cb_rd_wr_n,
      data_in  => flop_buffer_in.cb_data_in);


  histograma_mi_1 : entity work.histograma_mi
    generic map (
      NUMERO_BINS        => NUMERO_BINS,
      LARGURA_ADDR_BINS  => LARGURA_ADDR_BINS,
      LARGURA_BINS       => LARGURA_BINS,
      NUMERO_HISTOGRAMAS => NUMERO_HISTOGRAMAS)
    port map (
      clk                => clk,
      rst_n              => rst_n,
      wr_bank_sl_one_hot => flop_hist_in.wr_bank_sl_one_hot,
      valido_fxd_in      => flop_hist_in.fxd_in_valido,
      valido_flt_in      => flop_hist_in.flt_in_valido,
      valido_h2d_in      => flop_hist_in.flt_in_valido,
      bin_addr_fxd_in    => flop_hist_in.fxd_bin_addr,
      bin_addr_flt_in    => flop_hist_in.flt_bin_addr,
      clear_bin          => limpa_bins_i,
      rd_en              => hist_rd_en,
      rd_fxd_addr        => hist_fxd_bin_addr,
      rd_flt_addr        => hist_flt_bin_addr,
      rd_bin_fxd_out     => hist_fxd_qt,
      rd_bin_flt_out     => hist_flt_qt,
      rd_bin_h2d_out     => hist_h2d_qt,
      rd_bank_sl_one_hot => hist_shift_one_hot);

  calc_mi_1 : entity work.calc_mi
    generic map (
      NUMERO_BINS           => NUMERO_BINS,
      LARGURA_ADDR_BINS     => LARGURA_ADDR_BINS,
      NUMERO_HISTOGRAMAS    => NUMERO_HISTOGRAMAS,
      LARGURA_N_HISTOGRAMAS => LARGURA_N_HISTOGRAMAS,
      LARGURA_BINS          => LARGURA_BINS,
      NUMERO_PIXELS_QUADRO  => NUMERO_COLUNAS*NUMERO_LINHAS,
      LARGURA_N_PIXEIS      => LARGURA_N_PIXELS,
      LARGURA_MI_OUT        => LARGURA_MI_OUT,
      DEBUG                 => DEBUG)
    port map (
      clk                => clk,
      rst_n              => rst_n,
      hist_fxd_bin_addr  => hist_fxd_bin_addr,
      hist_flt_bin_addr  => hist_flt_bin_addr,
      hist_fxd_qt        => hist_fxd_qt,
      hist_flt_qt        => hist_flt_qt,
      hist_h2d_qt        => hist_h2d_qt,
      hist_shift_one_hot => hist_shift_one_hot,
      hist_rd_en         => hist_rd_en,

      prox_shift         => mi_prox_shift,
      curr_mi_out        => mi_out,
      curr_mi_out_valido => mi_out_valido);

end architecture fpga;

