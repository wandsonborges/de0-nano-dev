library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity nuc_core is
  generic (
    NBITS_DATA : integer := 8
    );
  port (

    enable     : in std_logic;
    pxl_raw    : in std_logic_vector(NBITS_DATA-1 downto 0);
    pxl_ref    : in std_logic_vector(NBITS_DATA-1 downto 0);
    mean_ref   : in std_logic_vector(NBITS_DATA-1 downto 0);
    pxl_out    : out std_logic_vector(NBITS_DATA-1 downto 0)
    );

end entity nuc_core;

architecture bhv of nuc_core is

  signal s_pxl_out : unsigned(NBITS_DATA downto 0) := (others => '0');
  signal s_pxl_out_filter : std_logic_vector(NBITS_DATA-1 downto 0) := (others => '0');  

begin

  s_pxl_out <= unsigned('0' & pxl_raw) + unsigned('0' & pxl_ref) - unsigned('0' & mean_ref);
  s_pxl_out_filter <= std_logic_vector(s_pxl_out(NBITS_DATA-1 downto 0)) when s_pxl_out(NBITS_DATA) = '0'
                      else (others => '1');

  pxl_out <= s_pxl_out_filter when enable = '1' else pxl_raw;

end architecture bhv;

  

  

  
    
