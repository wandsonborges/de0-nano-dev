-------------------------------------------------------------------------------
-- Title      : fifo_dados
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fifo_dados.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-09-02
-- Last update: 2014-06-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa a fifo de dados utilizando a megafunction da altera
-- Essa implementacao foi feita para que nos possamos parametrizar a fifo e
-- fazer algumas customizacoes.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-09-02  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity fifo_dados is
  
  generic (
    INTENDED_DEVICE     : string  := "Cyclone IV E";
    PROFUNDIDADE_FIFO   : integer := 512;
    LARGURA_FIFO        : integer := 16;
    TAMANHO_BURST       : integer := 16;
    N_BITS_PROFUNDIDADE : integer := 9);

  port (
    rst_n       : in  std_logic;
    rd_clk      : in  std_logic;
    rd_req      : in  std_logic;
    rd_vazia    : out std_logic;
    rd_burst_en : out std_logic;
    data_q      : out std_logic_vector(LARGURA_FIFO-1 downto 0);
    wr_clk      : in  std_logic;
    wr_req      : in  std_logic;
    wr_cheia    : out std_logic;
    wr_burst_en : out std_logic;
    data_d      : in  std_logic_vector(LARGURA_FIFO-1 downto 0));

end entity fifo_dados;

architecture fpga_arch of fifo_dados is
  component dcfifo is
    generic (
      intended_device_family : string;
      add_usedw_msb_bit      : string;
      lpm_numwords           : natural;
      lpm_showahead          : string;
      lpm_type               : string;
      lpm_width              : natural;
      lpm_widthu             : natural;
      overflow_checking      : string;
      rdsync_delaypipe       : natural;
      read_aclr_synch        : string;
      underflow_checking     : string;
      use_eab                : string;
      write_aclr_synch       : string;
      wrsync_delaypipe       : natural);
    port (
      rdclk   : in  std_logic;
      wrfull  : out std_logic;
      q       : out std_logic_vector (LARGURA_FIFO-1 downto 0);
      rdempty : out std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      wrusedw : out std_logic_vector (N_BITS_PROFUNDIDADE downto 0);
      aclr    : in  std_logic;
      data    : in  std_logic_vector (LARGURA_FIFO-1 downto 0);
      rdfull  : out std_logic;
      rdreq   : in  std_logic;
      rdusedw : out std_logic_vector (N_BITS_PROFUNDIDADE downto 0));
  end component dcfifo;

  signal rst : std_logic;

  signal wr_slots_usados : std_logic_vector(N_BITS_PROFUNDIDADE downto 0);
  signal rd_slots_usados : std_logic_vector(N_BITS_PROFUNDIDADE downto 0);

  signal wr_cheia_i, rd_vazia_i : std_logic;
begin  -- architecture fpga_arch
  rst         <= not rst_n;
  wr_burst_en <= '0' when unsigned(wr_slots_usados) > PROFUNDIDADE_FIFO - TAMANHO_BURST else
                 '1';

  rd_burst_en <= '0' when unsigned(rd_slots_usados) < TAMANHO_BURST else
                 '1';
  
  dcfifo_component : dcfifo
    generic map (
      intended_device_family => INTENDED_DEVICE,
      add_usedw_msb_bit      => "ON",
      lpm_numwords           => PROFUNDIDADE_FIFO,
      lpm_showahead          => "OFF",
      lpm_type               => "dcfifo",
      lpm_width              => LARGURA_FIFO,
      lpm_widthu             => N_BITS_PROFUNDIDADE+1,
      overflow_checking      => "ON",
      rdsync_delaypipe       => 4,
      read_aclr_synch        => "OFF",
      underflow_checking     => "ON",
      use_eab                => "ON",
      write_aclr_synch       => "OFF",
      wrsync_delaypipe       => 4
      )
    port map (
      rdclk   => rd_clk,
      wrclk   => wr_clk,
      wrreq   => wr_req,
      aclr    => rst,
      data    => data_d,
      rdreq   => rd_req,
      wrfull  => wr_cheia_i,
      q       => data_q,
      rdfull  => open,
      rdempty => rd_vazia_i,
      wrusedw => wr_slots_usados,
      rdusedw => rd_slots_usados
      );

  wr_cheia <= wr_cheia_i;
  rd_vazia <= rd_vazia_i;
  
  wr_clk_proc : process (wr_clk) is
  begin  -- process wr_clk_pproc
    if wr_clk'event and wr_clk = '1' then  -- rising clock edge
      assert not (wr_cheia_i = '1' and wr_req = '1')
        report "fifo_dados: escreveu na fila cheia" severity failure;
    end if;
  end process wr_clk_proc;

  rd_clk_proc : process (rd_clk) is
  begin  -- process wr_clk_pproc
    if rd_clk'event and rd_clk = '1' then  -- rising clock edge
  assert not (rd_vazia_i = '1' and rd_req = '1')
    report "fifo_dados: leu da fila vazia" severity failure;

    end if;
  end process rd_clk_proc;

  
end architecture fpga_arch;
