-------------------------------------------------------------------------------
-- Title      : endr_gen
-- Project    : 
-------------------------------------------------------------------------------
-- File       : addr_gen.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-09-02
-- Last update: 2014-12-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gerador de enderecos generico
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-09-02  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.uteis.all;

entity endr_gen is
  
  generic (
    BUFF_MAP : buffer_ping_pong_t:= MEM_MAP_BUFFER_DEFAULT;
    BURST_SIZE : integer := 1);

  port (
    clk, rst_n          : in  std_logic;
    endr_gen_in : in endr_gen_in_t;
    endr_gen_out : out endr_gen_out_t := ENDR_GEN_OUT_INIT
    );
end entity endr_gen;

architecture fpga_arch of endr_gen is
  signal endr_out_aux : endr_mem_t := (others => '0');
  signal endr_init_prox : endr_mem_t := (others => '0');
  signal endr_fim : endr_mem_t := (others => '1');
  signal endr_troca : endr_mem_t := (others => '1');
  signal buffer_atual, prox_buffer : buffer_id_t := (others => '0');
begin  -- architecture fpga_arch

  endr_gen_out.endr_out <= endr_out_aux;
  -- purpose: Implementa o gerador de enderecos
  -- type   : sequential
  -- inputs : clk, rst_n, endr_rst, endr_prox
  -- outputs: endr_out_aux
  gerador_proc : process (clk, rst_n) is
    variable prox_buffer_atual : buffer_id_t := (others => '0');
  begin  -- process gerador_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      endr_out_aux <= BUFF_MAP(0).inicio;
      endr_gen_out.buff_atual_out <= (others => '0');
      buffer_atual <= (others => '0');
      endr_init_prox <= (others => '0');
      endr_fim <= (others => '1');
      endr_troca <= (others => '1');
      prox_buffer <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if '1' = endr_gen_in.rst_endr then
        endr_out_aux <= BUFF_MAP(0).inicio;
        endr_gen_out.buff_atual_out <= (others => '0');
        buffer_atual <= (others => '0');
      elsif '1' = endr_gen_in.prox_endr then
        -- se estiver mudando de buffer, atualiza buffer_atual e buffer_out
        if endr_fim = endr_out_aux then
          endr_out_aux <= endr_init_prox;
          buffer_atual <= prox_buffer;
        else
          endr_out_aux <= std_logic_vector( (unsigned(endr_out_aux) + BURST_SIZE) );
        end if;
      end if;

      -- se ver o endereco de troca, ja avisa que pode ler do buffer atual
      if endr_troca = endr_out_aux then
        -- avisa para todos qual o buffer que contem dados mais atualizados
        endr_gen_out.buff_atual_out <= buffer_atual;
      end if;
      
      if '1' = endr_gen_in.buff_atual_in_en then
        prox_buffer <= endr_gen_in.buff_atual_in;
      else
        prox_buffer <= buffer_atual + '1';
        --prox_buffer <= std_logic_vector(unsigned(buffer_atual)+1);
      end if;

      -- recebe os valores de inicio e fim de buffer com antecedencia
      endr_init_prox <= BUFF_MAP(to_integer(unsigned(prox_buffer))).inicio;
      endr_fim <= BUFF_MAP(to_integer(unsigned(buffer_atual))).fim;
      endr_troca <= BUFF_MAP(to_integer(unsigned(buffer_atual))).troca;
      
    end if;
  end process gerador_proc;

end architecture fpga_arch;
