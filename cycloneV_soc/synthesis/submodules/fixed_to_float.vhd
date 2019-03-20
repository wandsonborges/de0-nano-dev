-------------------------------------------------------------------------------
-- Title      : fixed_to_float
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fixed_to_float.vhd
-- Author     :   <mdrumond-ivision@hailstorm-arch>
-- Company    : 
-- Created    : 2014-08-08
-- Last update: 2014-08-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Converte um numero de ponto fixo para ponto flutuante em 1 ciclo
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-08-08  1.0      mdrumond-ivision	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uteis.all;


entity fixed_to_float is
  
  generic (
    LARGURA_MANTISSA : integer := 8;
    LARGURA_EXPOENTE : integer := 8;
    LARGURA_FIXED    : integer := 8);

  port (
    clk, rst_n     : in  std_logic;
    valid_in       : in  std_logic;
    fixed_in       : in  std_logic_vector(LARGURA_FIXED-1 downto 0);
    valid_out      : out std_logic;
    float_mantissa : out std_logic_vector(LARGURA_MANTISSA-1 downto 0);
    float_expoente : out std_logic_vector(LARGURA_EXPOENTE-1 downto 0));

end entity fixed_to_float;

architecture fpga of fixed_to_float is

  signal expoente_calc : unsigned(LARGURA_EXPOENTE-1 downto 0);
  signal mantissa_calc : unsigned(LARGURA_MANTISSA-1 downto 0);
begin  -- architecture fpga

  in_proc: process(fixed_in) is
    variable expoente_aux : unsigned(LARGURA_EXPOENTE-1 downto 0);
  begin  -- process in_proc

    expoente_aux :=  acha_bit_mais_alto(LARGURA_EXPOENTE,
                                        unsigned(fixed_in)) + 1;
    mantissa_calc <= shifta_fixed_mantissa(LARGURA_MANTISSA, unsigned(fixed_in),
                                           expoente_aux);
    expoente_calc <= expoente_aux;
  end process in_proc;


  -- purpose: Flopa as saidas
  -- type   : sequential
  clk_proc: process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      valid_out <= '0';
      float_mantissa <= (others => '0');
      float_expoente <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      valid_out <= valid_in;
      float_mantissa <= std_logic_vector(mantissa_calc);
      float_expoente <= std_logic_vector(expoente_calc);
    end if;
  end process clk_proc;
end architecture fpga;
