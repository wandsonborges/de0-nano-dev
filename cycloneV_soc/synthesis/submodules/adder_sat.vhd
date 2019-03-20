-------------------------------------------------------------------------------
-- Title      : Somador SIGNED com saturacao
-- Project    : 
-------------------------------------------------------------------------------
-- File       : adder_sat.vhd
-- Author     :   <rodrigo.oliveira@TESLA>
-- Company    : 
-- Created    : 2014-10-17
-- Last update: 2015-01-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Se soma for maior que valor_max, result é valor_max. 
-- mesma coisa com valor_min.
-- Pode ser usado como filtro tbm. Basta jogar n2 para zero.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-10-17  1.0      rodrigo.oliveira	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.uteis.all;

entity adder_sat is
  
  generic (
    nbits    : integer := 8;
    valor_max : integer := 255;
    valor_min : integer := 0);

  port (
    rst_n  : in  std_logic;
    n1     : in  std_logic_vector(nbits-1 downto 0);
    n2     : in  std_logic_vector(nbits-1 downto 0);
    result : out std_logic_vector(nbits-1 downto 0)
    );

end entity adder_sat;

architecture bhv of adder_sat is

  signal prev_result : signed(nbits+1 downto 0) := (others => '0');
  signal prev_n1 : signed(nbits+1 downto 0) := (others => '0');
  signal prev_n2 : signed(nbits+1 downto 0) := (others => '0');
  signal real_result : signed(nbits+1 downto 0) := (others => '0');
  
begin  -- architecture bhv

  prev_n1 <= signed('0' & '0' & n1);
  prev_n2 <= signed(n2(nbits-1) & n2(nbits-1) & n2);
  
  soma: process (n1,n2, rst_n) is
  begin  -- process soma
    if (rst_n = '0') then
      prev_result <= (others => '0');
    else
      prev_result <= prev_n1 + prev_n2;
    end if;
  end process soma;

  sat_soma: process (prev_result) is
  begin  -- process sat_soma
    if (prev_result > valor_max) then
      real_result <= to_signed(valor_max, real_result'length);
    elsif (prev_result < valor_min) then
             real_result <= to_signed(valor_min, real_result'length);
           else
             real_result <= prev_result;
     end if;
           
  end process sat_soma;

 result <= std_logic_vector(real_result(nbits-1 downto 0));

end architecture bhv;
