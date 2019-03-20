-------------------------------------------------------------------------------
-- Title      : float_to_fixed
-- Project    : 
-------------------------------------------------------------------------------
-- File       : float_to_fixed.vhd
-- Author     :   <mdrumond-ivision@hailstorm-arch>
-- Company    : 
-- Created    : 2014-08-08
-- Last update: 2014-08-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Converte um numero de ponto flutuante para ponto fixo em 1 ciclo
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-08-08  1.0      mdrumond-ivision        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uteis.all;

entity float_to_fixed is
  
  generic (
    LARGURA_MANTISSA   : integer := 8;
    LARGURA_EXPOENTE   : integer := 8;
    LARGURA_FIXED_FRAC : integer := 8;
    LARGURA_FIXED_INT  : integer := 8);

  port (
    clk, rst_n  : in  std_logic;
    valid_in    : in  std_logic;
    mantissa_in : in  std_logic_vector(LARGURA_MANTISSA-1 downto 0);
    expoente_in : in  std_logic_vector(LARGURA_EXPOENTE-1 downto 0);
    valid_out   : out std_logic;
    fixed_out   : out std_logic_vector(LARGURA_FIXED_FRAC+LARGURA_FIXED_INT-1 downto 0));

end entity float_to_fixed;

architecture fpga of float_to_fixed is

  signal fixed_calc : unsigned(LARGURA_EXPOENTE-1 downto 0);
begin  -- architecture fpga

  -- purpose: Flopa as saidas
  -- type   : sequential
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      valid_out <= '0';
      fixed_out <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      valid_out <= valid_in;
      fixed_out <= std_logic_vector(shifta_float_mantissa(LARGURA_FIXED_INT,
                                                          LARGURA_FIXED_FRAC,
                                                          unsigned(mantissa_in),
                                                          signed(expoente_in)));
    end if;
  end process clk_proc;
  
end architecture fpga;
