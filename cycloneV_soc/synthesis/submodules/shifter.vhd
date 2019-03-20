-------------------------------------------------------------------------------
-- Title      : shifter_right
-- Project    : 
-------------------------------------------------------------------------------
-- File       : shifter.vhd
-- Author     :   <rodrigo.oliveira@TESLA>
-- Company    : 
-- Created    : 2014-09-11
-- Last update: 2014-09-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-09-11  1.0      rodrigo.oliveira	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.megafunc_pkg.all;
use work.uteis.all;

entity shifter_right is
  
  generic (
    WIDTH             : integer := 32;
    CONSTANT_TO_SHIFT : integer := 0);

  port (
    signal_unshifted : in  std_logic_vector(WIDTH-1 downto 0);
    signal_shifted   : out std_logic_vector(WIDTH-1 downto 0));

end entity shifter_right;

architecture bhv of shifter_right is

begin  -- architecture bhv

  signal_shifted <= std_logic_vector(shift_right(signed(signal_unshifted), CONSTANT_TO_SHIFT));

end architecture bhv;


