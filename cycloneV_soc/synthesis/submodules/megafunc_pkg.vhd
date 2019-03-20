-------------------------------------------------------------------------------
-- Title      : megafunc_pkg
-- Project    : 
-------------------------------------------------------------------------------
-- File       : megafunc_pkg.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-08-22
-- Last update: 2013-12-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Pacote com a declaracao dos componentes gerados automaticamente
--              pelo Quartus II.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-08-22  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library lpm;

use lpm.all;
use lpm.lpm_components.all;

library cycloneive;
use cycloneive.all;


package megafunc_pkg is

  component cycloneive_clkctrl is
    generic (
      clock_type        : string := "Global Clock";
      ena_register_mode : string := "falling edge";
      lpm_type          : string := "cycloneive_clkctrl");
    port (
      clkselect : in  std_logic_vector(1 downto 0);
      ena       : in  std_logic;
      inclk     : in  std_logic_vector(3 downto 0);
      outclk    : out std_logic);
  end component cycloneive_clkctrl;

--      lpm_hint           => "DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=9",
--      lpm_representation => "SIGNED",
--      lpm_type           => "LPM_MULT",

  component lpm_mult is
    generic (
      lpm_hint           : string;
      lpm_representation : string;
      lpm_type           : string;
      lpm_widtha         : natural;
      lpm_widthb         : natural;
      lpm_widthp         : natural);
    port (
      dataa  : in  std_logic_vector (lpm_widtha-1 downto 0);
      datab  : in  std_logic_vector (lpm_widthb-1 downto 0);
      result : out std_logic_vector (lpm_widthp-1 downto 0));
  end component lpm_mult;

  --component lpm_divide
  --  generic (
  --    lpm_drepresentation : string  := "SIGNED";
  --    lpm_hint            : string  := "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE";
  --    lpm_nrepresentation : string  := "SIGNED";
  --    lpm_pipeline        : natural := 6;
  --    lpm_type            : string  := "LPM_DIVIDE";
  --    lpm_widthd          : natural := 18;
  --    lpm_widthn          : natural := 18
  --    );
  --  port (
  --    clock    : in  std_logic;
  --    remain   : out std_logic_vector (lpm_widthd-1 downto 0);
  --    clken    : in  std_logic;
  --    denom    : in  std_logic_vector (lpm_widthd-1 downto 0);
  --    numer    : in  std_logic_vector (lpm_widthn-1 downto 0);
  --    quotient : out std_logic_vector (lpm_widthn-1 downto 0)
  --    );
  --end component;

  component pll_vid_mf is
    port (
      areset : in  std_logic := '0';
      inclk0 : in  std_logic := '0';
      c0     : out std_logic);
  end component pll_vid_mf;

  component pll_mf is
    port (
      areset : in  std_logic := '0';
      inclk0 : in  std_logic := '0';
      c0     : out std_logic;
      c1     : out std_logic;
      c2     : out std_logic;
      c3     : out std_logic);
  end component pll_mf;
end package megafunc_pkg;
