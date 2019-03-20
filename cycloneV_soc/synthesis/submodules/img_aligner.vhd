-------------------------------------------------------------------------------
-- Title      : img_aligner
-- Project    : 
-------------------------------------------------------------------------------
-- File       : img_aligner.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2014-06-04
-- Last update: 2017-08-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Bloco que recebe pixeis de duas imagens e alinha
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-06-04  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.uteis.all;

entity img_aligner is
  generic (
    TAMANHO_LINHA_IN    : integer := 320;
    TAMANHO_LINHA_OUT   : integer := 328;
    N_BITS_ENDR_LINHA   : integer := 9;
    PROFUNDIDADE_FIFO   : integer := 512;
    N_BITS_PROFUNDIDADE : integer := 9;
    LARGURA_PIXEL       : integer := 8;
    TAMANHO_BURST       : integer := 16
    );
  port (
    clk, rst_n : in std_logic;
    x_offset   : in std_logic_vector(N_BITS_ENDR_LINHA-1 downto 0);

    pixel_flt_align_in, pixel_fxd_align_in         : in  std_logic_vector(LARGURA_PIXEL-1 downto 0);
    pixel_flt_align_wr_req, pixel_fxd_align_wr_req : in  std_logic;
    pixel_flt_align_out, pixel_fxd_align_out       : out std_logic_vector(LARGURA_PIXEL-1 downto 0);
    pixel_align_valid_out                          : out std_logic
    );
end entity img_aligner;

architecture fpga of img_aligner is
  
  constant NUMERO_PIXEL_EXTRA : integer := TAMANHO_LINHA_IN - TAMANHO_LINHA_OUT;

  type estado_t is (ST_OCIOSO, ST_BORDA_INICIO, ST_ROI, ST_BORDA_FIM);

  type flop_controle_t is record
    estado     : estado_t;
    flt_wr_req : std_logic;
    pix_cnt    : unsigned(N_BITS_ENDR_LINHA downto 0);
  end record flop_controle_t;
  
  constant DEF_FLOP_CONTROLE : flop_controle_t := (
    estado     => ST_OCIOSO,
    flt_wr_req => '0',
    pix_cnt    => (others => '0'));
  
  signal flop_controle : flop_controle_t := DEF_FLOP_CONTROLE;

  signal pixel_flt_in_f1 : std_logic_vector(LARGURA_PIXEL-1 downto 0) := (others => '0');

  signal x_offset_i : std_logic_vector(N_BITS_ENDR_LINHA-1 downto 0);

  signal fifo_dados_flt_vazia, fifo_dados_fxd_vazia : std_logic := '0';
  signal fifo_dados_rd_req, fifo_dados_out_valid    : std_logic := '0';

  attribute noprune                    : boolean;
  signal out_pix_counter               : unsigned(N_BITS_ENDR_LINHA-1 downto 0) := (others => '0');
  attribute noprune of out_pix_counter : signal is true;

begin  -- architecture fpga

  -- purpose: Implementa o shifter
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process wr_clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_controle        <= DEF_FLOP_CONTROLE;
      fifo_dados_out_valid <= '0';
      pixel_flt_in_f1      <= (others => '0');
      x_offset_i           <= (others => '0');
      out_pix_counter <= (others => '0');
      --in_pix_counter_flt <= (others => '0');
      --in_pix_counter_fxd <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge

      flop_controle.flt_wr_req <= '0';
      case flop_controle.estado is
        when ST_OCIOSO =>
          if '1' = pixel_flt_align_wr_req then
            flop_controle.pix_cnt <= flop_controle.pix_cnt + 1;
            if unsigned(x_offset_i) = 0 then
              flop_controle.flt_wr_req <= '1';
              flop_controle.estado     <= ST_ROI;
            else
              if unsigned(x_offset_i) = 1 then
                flop_controle.estado <= ST_ROI;
              else
                flop_controle.estado <= ST_BORDA_INICIO;
              end if;
            end if;
          end if;
        -- le e joga fora o pixel ate completar o offset
        when ST_BORDA_INICIO =>
          if '1' = pixel_flt_align_wr_req then
            flop_controle.pix_cnt <= flop_controle.pix_cnt + 1;
            if unsigned(x_offset_i)-1 = flop_controle.pix_cnt then
              flop_controle.estado <= ST_ROI;
            end if;
          end if;
        -- le os pixels e so grava quando puder
        when ST_ROI =>
          if '1' = pixel_flt_align_wr_req then
            flop_controle.flt_wr_req <= '1';
            flop_controle.pix_cnt    <= flop_controle.pix_cnt + 1;
            if unsigned(x_offset_i)+ TAMANHO_LINHA_OUT-1 = flop_controle.pix_cnt then
              flop_controle.estado <= ST_BORDA_FIM;
            end if;
          end if;
        -- le e joga fora o pixel
        when ST_BORDA_FIM =>
          if '1' = pixel_flt_align_wr_req then
            flop_controle.pix_cnt <= flop_controle.pix_cnt + 1;
            if TAMANHO_LINHA_IN-1 = flop_controle.pix_cnt then
              flop_controle.pix_cnt <= (others => '0');
              flop_controle.estado  <= ST_OCIOSO;
              if unsigned(x_offset) >= NUMERO_PIXEL_EXTRA then
                x_offset_i <= std_logic_vector(to_unsigned(NUMERO_PIXEL_EXTRA-1, x_offset_i'length));
              else
                x_offset_i <= x_offset;
              end if;
              --x_offset_i <= (others => '0');
            end if;
          end if;
      end case;

      pixel_flt_in_f1      <= pixel_flt_align_in;
      fifo_dados_out_valid <= fifo_dados_rd_req;

      if '1' = fifo_dados_rd_req then
        out_pix_counter <= out_pix_counter + 1;
        if TAMANHO_LINHA_OUT-1 = out_pix_counter then
          out_pix_counter <= (others => '0');
        end if;
      end if;
    end if;

  end process clk_proc;

  fifo_dados_flt : entity work.fifo_dados_sync
    generic map (
      PROFUNDIDADE_FIFO   => 256,
      LARGURA_FIFO        => LARGURA_PIXEL,
      TAMANHO_BURST       => 8,
      N_BITS_PROFUNDIDADE => 8)
    port map (
      rst_n       => rst_n,
      clk         => clk,
      rd_req      => fifo_dados_rd_req,
      vazia       => fifo_dados_flt_vazia,
      rd_burst_en => open,
      data_q      => pixel_flt_align_out,

      wr_req      => flop_controle.flt_wr_req,
      cheia       => open,
      wr_burst_en => open,
      data_d      => pixel_flt_in_f1);

  fifo_dados_fxd : entity work.fifo_dados_sync
    generic map (
      PROFUNDIDADE_FIFO   => 1024,
      LARGURA_FIFO        => LARGURA_PIXEL,
      TAMANHO_BURST       => 8,
      N_BITS_PROFUNDIDADE => 10)
    port map (
      rst_n       => rst_n,
      clk         => clk,
      rd_req      => fifo_dados_rd_req,
      vazia       => fifo_dados_fxd_vazia,
      rd_burst_en => open,
      data_q      => pixel_fxd_align_out,

      wr_req      => pixel_fxd_align_wr_req,
      cheia       => open,
      wr_burst_en => open,
      data_d      => pixel_fxd_align_in);

  fifo_dados_rd_req     <= (not fifo_dados_fxd_vazia) and (not fifo_dados_flt_vazia);
  pixel_align_valid_out <= fifo_dados_out_valid;
  
end architecture fpga;
