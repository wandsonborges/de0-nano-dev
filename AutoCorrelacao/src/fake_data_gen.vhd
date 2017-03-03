library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fake_data_gen is
  
  generic (
    N_BITS_DATA     : natural := 8;
    N_PIXELS_TO_GEN : natural := 4096);

  port (
    clk, rst_n    : in  std_logic;
    get_next_pxl  : in  std_logic;
    pxl_to_insert : out std_logic_vector(N_BITS_DATA-1 downto 0)
    );

end entity fake_data_gen;

architecture bhv of fake_data_gen is

  signal counter : unsigned(N_BITS_DATA-1 downto 0) := (others => '0');
  
begin  -- architecture bhv

  proc: process (clk, rst_n) is
  begin  -- process proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      counter <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if get_next_pxl = '1' then
          counter <= counter+1;
      end if;
      else
        
    end if;
  end process proc;

  pxl_to_insert <= std_logic_vector(counter);
  
end architecture bhv;
