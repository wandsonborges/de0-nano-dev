library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity histograma_mi is

  generic (
    NUMERO_BINS       : integer := 32;
    LARGURA_ADDR_BINS : integer := 5;
    LARGURA_BINS      : integer := 16;
    NUMERO_HISTOGRAMAS     : integer := 32);

  port (
    clk, rst_n         : in  std_logic;
    wr_bank_sl_one_hot : in  std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);
    valido_fxd_in      : in  std_logic;
    valido_flt_in      : in  std_logic;
    valido_h2d_in      : in  std_logic;
    bin_addr_fxd_in    : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    bin_addr_flt_in    : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    clear_bin          : in  std_logic;
    rd_en              : in  std_logic;
    rd_fxd_addr        : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    rd_flt_addr        : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    rd_bin_fxd_out     : out std_logic_vector(LARGURA_BINS-1 downto 0);
    rd_bin_flt_out     : out std_logic_vector(LARGURA_BINS-1 downto 0);
    rd_bin_h2d_out     : out std_logic_vector(LARGURA_BINS-1 downto 0);
    rd_bank_sl_one_hot : in  std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0));

end entity histograma_mi;

architecture fpga of histograma_mi is
  signal buffer_flt_hist_addr, buffer_fxd_hist_addr : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);

  signal buffer_h2d_hist_addr : std_logic_vector(2*LARGURA_ADDR_BINS-1 downto 0);

  signal zera_bin_banks : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);

  signal incr_bin_banks_flt, incr_bin_banks_h2d : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);

  signal valido_flt_in_mask, valido_h2d_in_mask : std_logic_vector(NUMERO_HISTOGRAMAS-1 downto 0);

  signal rd_bin_out_banks_flt : std_logic_vector(LARGURA_BINS* NUMERO_HISTOGRAMAS-1 downto 0);
  signal rd_bin_out_banks_h2d : std_logic_vector(LARGURA_BINS* NUMERO_HISTOGRAMAS-1 downto 0);

begin  -- architecture fpga

  zera_bin_banks     <= (others => clear_bin);
  valido_flt_in_mask <= (others => (valido_flt_in));
  valido_h2d_in_mask <= (others => (valido_h2d_in));
  incr_bin_banks_flt <= valido_flt_in_mask and wr_bank_sl_one_hot;
  incr_bin_banks_h2d <= valido_h2d_in_mask and wr_bank_sl_one_hot;

  buffer_fxd_hist_addr <= rd_fxd_addr when '1' = rd_en else
                          bin_addr_fxd_in;
  buffer_flt_hist_addr <= rd_flt_addr when '1' = rd_en else
                          bin_addr_flt_in;
  buffer_h2d_hist_addr <= rd_fxd_addr & rd_flt_addr when '1' = rd_en else
                          bin_addr_fxd_in & bin_addr_flt_in;
  
  buffer_histograma_fxd : entity work.buffer_histograma
    generic map (
      NUMERO_BINS       => NUMERO_BINS,
      LARGURA_ADDR_BINS => LARGURA_ADDR_BINS,
      LARGURA_BINS      => LARGURA_BINS)
    port map (
      clk       => clk,
      rst_n     => rst_n,
      bin_addr  => buffer_fxd_hist_addr,
      incr_bin  => valido_fxd_in,
      zera_bin  => clear_bin,
      value_out => rd_bin_fxd_out);

  -- gera os buffer onde serao guardados os histogramas
  generate_buffer_histograma : for i in 0 to NUMERO_HISTOGRAMAS-1 generate
    buffer_histograma_2d : entity work.buffer_histograma
      generic map (
        NUMERO_BINS       => NUMERO_BINS*NUMERO_BINS,
        LARGURA_ADDR_BINS => 2*LARGURA_ADDR_BINS,
        LARGURA_BINS      => LARGURA_BINS)
      port map (
        clk       => clk,
        rst_n     => rst_n,
        bin_addr  => buffer_h2d_hist_addr,
        incr_bin  => incr_bin_banks_h2d(i),
        zera_bin  => zera_bin_banks(i),
        value_out => rd_bin_out_banks_h2d(LARGURA_BINS*(i+1)-1 downto LARGURA_BINS*i));

    buffer_histograma_flt : entity work.buffer_histograma
      generic map (
        NUMERO_BINS       => NUMERO_BINS,
        LARGURA_ADDR_BINS => LARGURA_ADDR_BINS,
        LARGURA_BINS      => LARGURA_BINS)
      port map (
        clk       => clk,
        rst_n     => rst_n,
        bin_addr  => buffer_flt_hist_addr,
        incr_bin  => incr_bin_banks_flt(i),
        zera_bin  => zera_bin_banks(i),
        value_out => rd_bin_out_banks_flt(LARGURA_BINS*(i+1)-1 downto LARGURA_BINS*i));
  end generate generate_buffer_histograma;

  -- multiplexador para a saida da leitura de dados do histograma do fixed
  multiplexador_saida_flt : entity work.multiplexador_one_hot
    generic map (
      LARGURA_PALAVRA => LARGURA_BINS,
      NUMERO_PALAVRAS => NUMERO_HISTOGRAMAS)
    port map (
      data_in  => rd_bin_out_banks_flt,
      data_out => rd_bin_flt_out,
      data_sl  => rd_bank_sl_one_hot);


  -- multiplexador para a saida da leitura de dados do histograma do hist_2d
  multiplexador_saida_h2d : entity work.multiplexador_one_hot
    generic map (
      LARGURA_PALAVRA => LARGURA_BINS,
      NUMERO_PALAVRAS => NUMERO_HISTOGRAMAS)
    port map (
      data_in  => rd_bin_out_banks_h2d,
      data_out => rd_bin_h2d_out,
      data_sl  => rd_bank_sl_one_hot);

end architecture fpga;
