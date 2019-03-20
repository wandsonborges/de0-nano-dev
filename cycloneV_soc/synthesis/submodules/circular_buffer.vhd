 -------------------------------------------------------------------------------
-- Title      : circular_buffer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : circular_buffer.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-19
-- Last update: 2014-08-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa um buffer circular em BRAM utilizando uma porta de
-- entrada/saida
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-19  1.0      mdrumond	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity circular_buffer is
  
  generic (
    NUMERO_WORDS : integer := 128;
    LARGURA_ADDR : integer := 6;
    LARGURA_WORD : integer := 8);

  port (
    clk, rst_n : in std_logic;
    rd_addr  : in  std_logic_vector(LARGURA_ADDR-1 downto 0);
    data_out : out std_logic_vector(LARGURA_WORD-1 downto 0);
    rd_wr_n  : in  std_logic;
    data_in  : in  std_logic_vector(LARGURA_WORD-1 downto 0));
end entity circular_buffer;

architecture fpga of circular_buffer is
  attribute ramstyle         : string;
  --attribute ramstyle of fpga : architecture is "M9K";
  attribute ramstyle of fpga : architecture is "logic";

  subtype ram_word_t is std_logic_vector(LARGURA_WORD-1 downto 0);

  type ram_block_t is array (0 to NUMERO_WORDS-1) of ram_word_t;
  signal ram_block : ram_block_t;
  
  signal circular_pointer : unsigned(LARGURA_ADDR-1 downto 0);
  
begin  -- architecture fpga

  -- purpose: Implementa o buffer circular
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_rpoc: process (clk, rst_n) is
  begin  -- process clk_rpoc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      circular_pointer <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if '0' = rd_wr_n then
        circular_pointer <= circular_pointer  + 1;
      end if;
    end if;
  end process clk_rpoc;

  -- purpose: Processo de memoria
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  mem_proc: process (clk) is
    variable addr_aux : unsigned(LARGURA_ADDR-1 downto 0);
  begin  -- process mem_proc
    if clk'event and clk = '1' then  -- rising clock edge
      if '0' = rd_wr_n then
        addr_aux := circular_pointer;
      else
        -- circular pointer aponta para o endereco mais alto
        addr_aux := (circular_pointer-1) - unsigned(rd_addr);
      end if;

      if '0' = rd_wr_n then
        ram_block(to_integer(addr_aux)) <= data_in;
      end if;
      data_out <= ram_block(to_integer(addr_aux));
      
    end if;
  end process mem_proc;

end architecture fpga;
