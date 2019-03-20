-------------------------------------------------------------------------------
-- Title      : fifo_dados_sync
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fifo_dados_sync.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-09-02
-- Last update: 2014-07-28
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

entity fifo_dados_sync is
  
  generic (
    INTENDED_DEVICE     : string  := "Cyclone IV E";
    PROFUNDIDADE_FIFO   : integer := 512;
    LARGURA_FIFO        : integer := 16;
    TAMANHO_BURST       : integer := 16;
    N_BITS_PROFUNDIDADE : integer := 9);

  port (
    rst_n, clk  : in  std_logic;
    rd_req      : in  std_logic;
    vazia       : out std_logic;
    rd_burst_en : out std_logic;
    data_q      : out std_logic_vector(LARGURA_FIFO-1 downto 0);
    wr_req      : in  std_logic;
    cheia       : out std_logic;
    wr_burst_en : out std_logic;
    data_d      : in  std_logic_vector(LARGURA_FIFO-1 downto 0));

end entity fifo_dados_sync;

architecture fpga of fifo_dados_sync is

  component scfifo
    generic (
      add_ram_output_register : string;
      intended_device_family  : string;
      lpm_numwords            : natural;
      lpm_showahead           : string;
      lpm_type                : string;
      lpm_width               : natural;
      lpm_widthu              : natural;
      overflow_checking       : string;
      underflow_checking      : string;
      use_eab                 : string
      );
    port (
      clock : in  std_logic;
      usedw : out std_logic_vector (N_BITS_PROFUNDIDADE-1 downto 0);
      empty : out std_logic;
      full  : out std_logic;
      q     : out std_logic_vector (LARGURA_FIFO-1 downto 0);
      wrreq : in  std_logic;
      aclr  : in  std_logic;
      data  : in  std_logic_vector (LARGURA_FIFO-1 downto 0);
      rdreq : in  std_logic
      );
  end component;

  constant DEBUG_EN : boolean := false;

  signal rst                : std_logic;
  signal cheia_i, vazia_i   : std_logic;
  signal usedw              : std_logic_vector(N_BITS_PROFUNDIDADE-1 downto 0);
  signal usedw_real         : std_logic_vector(N_BITS_PROFUNDIDADE downto 0);
  signal erro_wr, erro_rd   : std_logic := '0';
  signal wr_req_i, rd_req_i : std_logic := '0';
begin  -- architecture fpga

  scfifo_component : scfifo
    generic map (
      add_ram_output_register => "ON",
      intended_device_family  => INTENDED_DEVICE,
      lpm_numwords            => PROFUNDIDADE_FIFO,
      lpm_showahead           => "OFF",
      lpm_type                => "scfifo",
      lpm_width               => LARGURA_FIFO,
      lpm_widthu              => N_BITS_PROFUNDIDADE,
      overflow_checking       => "OFF",
      underflow_checking      => "OFF",
      use_eab                 => "ON"   -- marca para usar ou nao block ram
      )
    port map (
      aclr  => rst,
      clock => clk,
      data  => data_d,
      rdreq => rd_req_i,
      wrreq => wr_req_i,
      usedw => usedw,
      empty => vazia_i,
      full  => cheia_i,
      q     => data_q
      );

  cheia <= cheia_i;
  vazia <= vazia_i;

  wr_req_i <= wr_req and not erro_wr;
  rd_req_i <= rd_req and not erro_rd;

  usedw_real <= cheia_i & usedw;

  rst <= not rst_n;

  wr_burst_en <= '0' when unsigned(usedw_real) > PROFUNDIDADE_FIFO - TAMANHO_BURST else
                 '1';

  rd_burst_en <= '0' when unsigned(usedw_real) < TAMANHO_BURST else
                 '1';

  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if '0' = rst_n then
      erro_rd <= '0';
      erro_wr <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if '1'= cheia_i and '1' = wr_req then
        assert false
          report "fifo_dados_sync: escreveu na fila cheia" severity failure;
        if DEBUG_EN then
          erro_wr <= '1';
        else
          erro_wr <= '0';
        end if;
      end if;

      if vazia_i = '1' and rd_req = '1' then
        assert false
          report "fifo_dados_sync: leu da fila vazia" severity failure;
        if DEBUG_EN then
          erro_rd <= '1';
        else
          erro_rd <= '0';
        end if;
      end if;
    end if;
  end process clk_proc;

  
end architecture fpga;
