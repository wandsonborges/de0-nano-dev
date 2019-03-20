-------------------------------------------------------------------------------
-- Title      : filter_line_buffer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : filter_line_buffer.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-14
-- Last update: 2014-01-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates data for the line buffer
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-14  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity filter_line_buffer is
  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9);

  port (
    clk, rst_n                   : in  std_logic;
    pixel_in                     : in  pixel_t;
    buffer_wr_sl                 : in  std_logic_vector(1 downto 0);
    pix_wr_en                    : in  std_logic;
    pixel_wr_addr, pixel_rd_addr : in  std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);
    pixel_out_atual_linha        : out std_logic_vector(C_LARGURA_PIXEL-1 downto 0);
    pixel_out_ultima_linha       : out std_logic_vector(C_LARGURA_PIXEL-1 downto 0));

end entity filter_line_buffer;

architecture fpga of filter_line_buffer is
  attribute ramstyle         : string;
  attribute ramstyle of fpga : architecture is "M9K";

  subtype pixel_2x_t is std_logic_vector(2*C_LARGURA_PIXEL-1 downto 0);
  signal ram_wr_en   : std_logic := '0';

  signal buffer_sl_atual_linha, buffer_sl_ultima_linha : unsigned(1 downto 0) := (others => '0');

  signal ram_wr_addr, ram_rd_addr : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0) := (others => '0');

  type buffer_linhas_t is array (0 to NUMERO_COLUNAS-1) of pixel_t;
  signal buffer_linha_a, buffer_linha_b, buffer_linha_c : buffer_linhas_t;

  type ram_port_buffers_t is array (0 to 2) of pixel_t;
  signal rdout_buffers : ram_port_buffers_t;

begin  -- architecture fpga

  ram_rd_addr <= unsigned(pixel_rd_addr);

  buffer_sl_atual_linha <= "00" when buffer_wr_sl = "01" else
                           "01" when buffer_wr_sl = "10" else
                           "10" when buffer_wr_sl = "00" else
                           "00";
  buffer_sl_ultima_linha <= "00" when buffer_wr_sl = "10" else
                            "01" when buffer_wr_sl = "00" else
                            "10" when buffer_wr_sl = "01" else
                            "00";
  ram_wr_addr <= unsigned(pixel_wr_addr);
  ram_wr_en   <= pix_wr_en;

  
  pixel_out_atual_linha  <= rdout_buffers(to_integer(buffer_sl_atual_linha));
                            
  pixel_out_ultima_linha <= rdout_buffers(to_integer(buffer_sl_ultima_linha));


  -- purpose: Implementa o sobel seguido do cordic
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if clk'event and clk = '1' then  -- rising clock edge
      -- implementa ram com addr registrado
      if ram_wr_en = '1' and unsigned(buffer_wr_sl) = 0 then
        buffer_linha_a(to_integer(ram_wr_addr)) <= pixel_in;
      end if;
      rdout_buffers(0) <= buffer_linha_a(to_integer(ram_rd_addr));

      if ram_wr_en = '1' and unsigned(buffer_wr_sl) = 1 then
        buffer_linha_b(to_integer(ram_wr_addr)) <= pixel_in;
      end if;
      rdout_buffers(1) <= buffer_linha_b(to_integer(ram_rd_addr));

      if ram_wr_en = '1' and unsigned(buffer_wr_sl) = 2 then
        buffer_linha_c(to_integer(ram_wr_addr)) <= pixel_in;
      end if;
      rdout_buffers(2) <= buffer_linha_c(to_integer(ram_rd_addr));

    end if;
  end process clk_proc;


end architecture fpga;
