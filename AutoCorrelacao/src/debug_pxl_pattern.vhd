library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity debug_pxl_pattern is
  
  port (
    clk, rst_n    : in  std_logic;
    pxl_in        : in  std_logic_vector(7 downto 0);
    pxl_valid     : in  std_logic;
    debug_out     : out std_logic_vector(7 downto 0)
    );

end entity debug_pxl_pattern;

architecture bhv of debug_pxl_pattern is

  signal count_pxls         : unsigned(4 downto 0) := (others => '0');
  signal first_is_zero      : std_logic := '0';
  signal sequence_respected : std_logic := '0';
  signal pxl_saved : std_logic_vector( 7 downto 0) := (others => '0');
  
begin  -- architecture bhv

  proc: process (clk, rst_n) is
    variable first_read : std_logic := '0';
  begin  -- process proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      first_is_zero <= '0';
      sequence_respected <= '0';
      pxl_saved <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if pxl_valid = '1' and first_read = '0' then
        first_read := '1';
        debug_out <= pxl_in;
      end if;
        
    end if;
  end process proc;

--  debug_out <= first_is_zero;
  
end architecture bhv;
