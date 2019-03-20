-------------------------------------------------------------------------------
-- Title      : buffer_histograma
-- Project    : 
-------------------------------------------------------------------------------
-- File       : buffer_histograma.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-19
-- Last update: 2014-06-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o buffer para um histograma em BRAM com 2 portas
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

library altera_mf;
use altera_mf.altera_mf_components.all;

use work.uteis.all;

entity buffer_histograma is
  
  generic (
    NUMERO_BINS       : integer := 32;
    LARGURA_ADDR_BINS : integer := 5;
    LARGURA_BINS      : integer := 16);

  port (
    clk, rst_n : in  std_logic;
    bin_addr   : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
    incr_bin   : in  std_logic;
    zera_bin   : in  std_logic;
    value_out  : out std_logic_vector(LARGURA_BINS-1 downto 0));

end entity buffer_histograma;

architecture fpga of buffer_histograma is
  attribute ramstyle         : string;
  attribute ramstyle of fpga : architecture is "M9K";
  --attribute ramstyle of fpga : architecture is "logic";

  subtype ram_word_t is std_logic_vector(LARGURA_BINS-1 downto 0);

  type hist_ram_block_t is array (0 to NUMERO_BINS-1) of ram_word_t;
  signal hist_ram_block : hist_ram_block_t;
  signal read_reg       : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal curr_wr_addr   : std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
  signal last_read_incr : std_logic_vector(LARGURA_BINS-1 downto 0);
  signal write_bin_en   : std_logic;
  signal zera_bin_i     : std_logic;

  subtype incrementa_t is std_logic_vector(LARGURA_BINS-1 downto 0);
  function incrementa_bin (
    signal valor_atual_bin : std_logic_vector(LARGURA_BINS-1 downto 0))
    return incrementa_t is
  begin
    if unsigned(valor_atual_bin) = (2** LARGURA_BINS)-1 then
      return valor_atual_bin;
    else
      return std_logic_vector(unsigned(valor_atual_bin) +1);
    end if;
  end incrementa_bin;

  signal incr_value_aux, incr_value_aux2 : std_logic_vector(LARGURA_BINS-1 downto 0);

  component altsyncram

    generic (

      address_aclr_a : string := "UNUSED";
      address_aclr_b : string := "NONE";
      address_reg_b : string := "CLOCK1";
      byte_size : natural := 8;
      byteena_aclr_a : string := "UNUSED";
      byteena_aclr_b : string := "NONE";
      byteena_reg_b : string := "CLOCK1";
      clock_enable_core_a : string := "USE_INPUT_CLKEN";
      clock_enable_core_b : string := "USE_INPUT_CLKEN";
      clock_enable_input_a : string := "NORMAL";
      clock_enable_input_b : string := "NORMAL";
      clock_enable_output_a : string := "NORMAL";
      clock_enable_output_b : string := "NORMAL";
      intended_device_family : string := "unused";
      enable_ecc : string := "FALSE";
      implement_in_les : string := "OFF";
      indata_aclr_a : string := "UNUSED";
      indata_aclr_b : string := "NONE";
      indata_reg_b : string := "CLOCK1";
      init_file : string := "UNUSED";
      init_file_layout : string := "PORT_A";
      maximum_depth : natural := 0;
      numwords_a : natural := 0;
      numwords_b : natural := 0;
      operation_mode : string := "BIDIR_DUAL_PORT";
      outdata_aclr_a : string := "NONE";
      outdata_aclr_b : string := "NONE";
      outdata_reg_a : string := "UNREGISTERED";
      outdata_reg_b : string := "UNREGISTERED";
      power_up_uninitialized : string := "FALSE";
      ram_block_type : string := "AUTO";
      rdcontrol_aclr_b : string := "NONE";
      rdcontrol_reg_b : string := "CLOCK1";
      read_during_write_mode_mixed_ports : string := "DONT_CARE";
      read_during_write_mode_port_a : string := "NEW_DATA_NO_NBE_READ";
      read_during_write_mode_port_b : string := "NEW_DATA_NO_NBE_READ";
      width_a : natural;
      width_b : natural := 1;
      width_byteena_a : natural := 1;
      width_byteena_b : natural := 1;
      widthad_a : natural;
      widthad_b : natural := 1;
      wrcontrol_aclr_a : string := "UNUSED";
      wrcontrol_aclr_b : string := "NONE";
      wrcontrol_wraddress_reg_b : string := "CLOCK1";
      lpm_hint : string := "UNUSED";
      lpm_type : string := "altsyncram"
      );

    port(

      aclr0 : in std_logic := '0';
      aclr1 : in std_logic := '0';
      address_a : in std_logic_vector(widthad_a-1 downto 0);
      address_b : in std_logic_vector(widthad_b-1 downto 0) := (others => '1');
      addressstall_a : in std_logic := '0';
      addressstall_b : in std_logic := '0';
      byteena_a : in std_logic_vector(width_byteena_a-1 downto 0) := (others => '1');
      byteena_b : in std_logic_vector(width_byteena_b-1 downto 0) := (others => '1');
      clock0 : in std_logic := '1';
      clock1 : in std_logic := '1';
      clocken0 : in std_logic := '1';
      clocken1 : in std_logic := '1';
      clocken2 : in std_logic := '1';
      clocken3 : in std_logic := '1';
      data_a : in std_logic_vector(width_a-1 downto 0) := (others => '1');
      data_b : in std_logic_vector(width_b-1 downto 0) := (others => '1');
      eccstatus : out std_logic_vector(2 downto 0);
      q_a : out std_logic_vector(width_a-1 downto 0);
      q_b : out std_logic_vector(width_b-1 downto 0);
      rden_a : in std_logic := '1';
      rden_b : in std_logic := '1';
      wren_a : in std_logic := '0';
      wren_b : in std_logic := '0'

      );

  end component;
  
begin  -- architecture fpga


  -- purpose: Implementa o buffer para o histograma
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
    variable incr_value_aux : std_logic_vector(LARGURA_BINS-1 downto 0);
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      curr_wr_addr   <= (others => '0');
      last_read_incr <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge

      zera_bin_i <= zera_bin;


      -- zera a bin ou incrementa a bin
      write_bin_en <= '0';
      if ('1' = zera_bin) or ('1' = incr_bin) then
        write_bin_en <= '1';
        curr_wr_addr <= bin_addr;
      end if;

      if '1' = write_bin_en then
        last_read_incr <= incr_value_aux2;
      end if;
      
    end if;
  end process clk_proc;

  incr_value_aux <= last_read_incr when (curr_wr_addr = bin_addr) and ('1' = incr_bin) else
                    (others => '1') when '1' = zera_bin_i else
                    read_reg;
  incr_value_aux2 <= std_logic_vector(unsigned(incr_value_aux) +1);


  -- purpose: Implementa a BRAM
  -- type   : sequential
  -- inputs : clk
  -- outputs: 
  mem_proc : process (clk) is
  begin  -- process mem_proc
    if clk'event and clk = '1' then     -- rising clock edge
      -- parte da memoria - esses regs não sao resetados
      read_reg <= hist_ram_block(to_integer(unsigned(bin_addr)));
      -- 
      if '1' = write_bin_en then
        hist_ram_block(to_integer(unsigned(curr_wr_addr)))
          <= incr_value_aux2;
      end if;
    end if;
  end process mem_proc;
  value_out <= read_reg;
end architecture fpga;
