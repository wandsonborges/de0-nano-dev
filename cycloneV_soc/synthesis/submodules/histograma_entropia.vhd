-------------------------------------------------------------------------------
-- Title      : histograma_entropia
-- Project    : 
-------------------------------------------------------------------------------
-- File       : histograma_entropia.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-19
-- Last update: 2014-08-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o modulo de histograma para entropia. Esse modulo
--              e otimizado, utiliza um multiplexador one hot na saida
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-19  1.0      mdrumond        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity histograma_entropia is

  generic (
    NUMERO_BINS        : integer := 32;
    LARGURA_ADDR_BINS  : integer := 5;
    LARGURA_BINS       : integer := 16;
    NUMERO_HISTOGRAMAS : integer := 32);

  port (
    clk, rst_n         : in  std_logic;
    wr_bank_sl_one_hot : in  std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    valor_in           : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    ang_count_in       : in  std_logic;
    valido_in          : in  std_logic;
    clear_bin          : in  std_logic;
    rd_en              : in  std_logic;
    rd_addr            : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    rd_bin_out         : out std_logic_vector(LARGURA_BINS-1 downto 0);
    rd_total_out       : out std_logic_vector(LARGURA_BINS-1 downto 0);
    rd_bank_sl_one_hot : in  std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0));

end entity histograma_entropia;

architecture fpga of histograma_entropia is
  signal buffer_hist_addr               : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal incr_bin_banks, zera_bin_banks : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
  signal valido_in_mask                 : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
  signal rd_bin_out_banks               : std_logic_vector(LARGURA_BINS* NUMERO_HISTOGRAMAS-1 downto 0);

  signal total_counter, new_total_counter : std_logic_vector(LARGURA_BINS* NUMERO_HISTOGRAMAS-1 downto 0);

  signal last_total_counter_incr : std_logic                                       := '0';
  signal last_wr_bank_sl         : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0) := (others => '0');
  signal total_counter_curr_sl   : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);

  signal total_counter_curr_bank      : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal last_total_counter_curr_bank : std_logic_vector(LARGURA_BINS-1 downto 0);
  
begin  -- architecture fpga
  -- gera os buffer onde serao guardados os histogramas
  generate_buffer_histograma : for i in 0 to NUMERO_HISTOGRAMAS-1 generate
    buffer_histograma_1 : entity work.buffer_histograma
      generic map (
        NUMERO_BINS       => NUMERO_BINS,
        LARGURA_ADDR_BINS => LARGURA_ADDR_BINS,
        LARGURA_BINS      => LARGURA_BINS)
      port map (
        clk       => clk,
        rst_n     => rst_n,
        bin_addr  => buffer_hist_addr,
        incr_bin  => incr_bin_banks(i),
        zera_bin  => zera_bin_banks(i),
        value_out => rd_bin_out_banks(LARGURA_BINS*(i+1)-1 downto LARGURA_BINS*i));
  end generate generate_buffer_histograma;

  -- multiplexador para a saida da leitura de dados do histograma
  multiplexador_saida_leitura : entity work.multiplexador_one_hot
    generic map (
      LARGURA_PALAVRA => LARGURA_BINS,
      NUMERO_PALAVRAS => NUMERO_HISTOGRAMAS)
    port map (
      data_in  => rd_bin_out_banks,
      data_out => rd_bin_out,
      data_sl  => rd_bank_sl_one_hot);

  zera_bin_banks   <= (others => clear_bin);
  valido_in_mask   <= (others => (valido_in and ang_count_in));
  incr_bin_banks   <= valido_in_mask and wr_bank_sl_one_hot;
  buffer_hist_addr <= rd_addr when '1' = rd_en else
                      valor_in;

  total_counter_curr_sl <= wr_bank_sl_one_hot when '0' = rd_en else
                           rd_bank_sl_one_hot;
  multiplexador_total_counter : entity work.multiplexador_one_hot
    generic map (
      LARGURA_PALAVRA => LARGURA_BINS,
      NUMERO_PALAVRAS => NUMERO_HISTOGRAMAS)
    port map (
      data_in  => total_counter,
      data_out => total_counter_curr_bank,
      data_sl  => total_counter_curr_sl);

  -- purpose: Clk proc
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      total_counter                <= (others => '0');
      last_wr_bank_sl              <= (others => '0');
      last_total_counter_curr_bank <= (others => '0');
      last_total_counter_incr      <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if '1' = valido_in and '1' = ang_count_in then
        last_total_counter_incr <= '1';
      else
        last_total_counter_incr <= '0';
      end if;

      -- satura o contador total
      if unsigned(total_counter_curr_bank) /= (2**LARGURA_BINS)-1 then
        last_total_counter_curr_bank <= std_logic_vector(unsigned(total_counter_curr_bank) +1);
      else
        last_total_counter_curr_bank <= total_counter_curr_bank;
      end if;
      
      last_wr_bank_sl <= wr_bank_sl_one_hot;

      if '1' = clear_bin then
        total_counter <= (others => '0');
      else
        for i in 0 to NUMERO_HISTOGRAMAS-1 loop
          if '1' = last_wr_bank_sl(i) and '1' = last_total_counter_incr then
            total_counter(LARGURA_BINS*(i+1)-1 downto LARGURA_BINS*i) <=
              last_total_counter_curr_bank;
          end if;
        end loop;  -- i
      end if;

      rd_total_out <= total_counter_curr_bank;
    end if;
  end process clk_proc;
  
end architecture fpga;
