library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

LIBRARY lpm;
USE lpm.lpm_components.all;


entity window_gen_top is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12
    );

  port (
    --clk and reset_n
    CLOCK_50 : in std_logic;
    SW       : in std_logic_vector(3 downto 0);
    LED : out std_logic_vector(7 downto 0)
    );               

end entity window_gen_top;

architecture bhv of window_gen_top is

  signal window_data_reg : window_type := (others => (others => (others => '0')));
  
begin
  window_gen_1: entity work.window_gen
    generic map (
      COLS        => 640,
      LINES       => 480,
      NBITS_COLS  => 10,
      NBITS_LINES => 10)
    port map (
      clk          => CLOCK_50,
      rst_n        => SW(0),
      start_conv   => SW(1),
      pxl_valid    => SW(2),
      pxl_data     => SW(3 downto 0) & SW(3 downto 0),
      window_valid => open,
      window_data  => window_data_reg);

  LED(7 downto 0) <= window_data_reg(0)(0);
end architecture bhv;
