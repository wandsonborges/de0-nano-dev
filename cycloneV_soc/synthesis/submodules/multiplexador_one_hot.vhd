-------------------------------------------------------------------------------
-- Title      : multiplexador_one_hot
-- Project    : 
-------------------------------------------------------------------------------
-- File       : multiplexador_one_hot.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-20
-- Last update: 2013-11-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa um multiplexiador com sinal de selecao do tipo one
-- hot, para a multiplexacao de n sinais, sao passados n bits e apenas um
-- desses bits esta em 1. Esse bit marca o sinal a ser utilizado
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-20  1.0      mdrumond	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity multiplexador_one_hot is
  
  generic (
    LARGURA_PALAVRA : integer := 16;
    NUMERO_PALAVRAS  : integer := 32);

  port (
    data_in  : in  std_logic_vector(LARGURA_PALAVRA*NUMERO_PALAVRAS-1 downto 0);
    data_out : out std_logic_vector(LARGURA_PALAVRA-1 downto 0);
    data_sl  : in  std_logic_vector(NUMERO_PALAVRAS-1 downto 0));

end entity multiplexador_one_hot;

architecture fpga of multiplexador_one_hot is
  subtype multiplexador_out_t is std_logic_vector(LARGURA_PALAVRA-1 downto 0);
  -- implementa um multiplexador com 2 niveis de porta logica: 1 and e 1 or
  function multiplexador (
    signal data_in : std_logic_vector(LARGURA_PALAVRA*NUMERO_PALAVRAS-1 downto 0);
    signal data_sl : std_logic_vector(NUMERO_PALAVRAS-1 downto 0))
    return multiplexador_out_t is
    variable one_hot_out : multiplexador_out_t;
  begin
    one_hot_out := (others => '0');
    for i in 0 to NUMERO_PALAVRAS-1 loop
      if data_sl(i) = '1' then
        one_hot_out := one_hot_out or data_in(LARGURA_PALAVRA*(i+1)-1 downto LARGURA_PALAVRA*i);
      end if;
    end loop;  -- i
    return one_hot_out;
  end;
    
begin  -- architecture fpga

  data_out <= multiplexador(data_in, data_sl);

end architecture fpga;
