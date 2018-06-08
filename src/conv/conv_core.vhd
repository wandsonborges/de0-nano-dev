
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

LIBRARY lpm;
USE lpm.lpm_components.all;

entity conv_core is
  port (clk      : in std_logic;
        rst_n    : in std_logic;
        kernel   : in kernel_type;
        data_in : in window_type;
        data_in_valid : in std_logic;
        pxl_result : out std_logic_vector(NBITS_DATA-1 downto 0);
        pxl_result_valid : out std_logic
        );
end entity conv_core;

architecture bhv of conv_core is
  
  signal conv_result : result_type;
  signal numerator : window_unsig_type;
  signal pxl_result_tmp : std_logic_vector(NBITS_DATA downto 0);
begin
  
GEN_CONV_MULTIPLIERS:
for j in 0 to KERNEL_H-1 generate
  GEN_COLUMN_MULTIPLIERS:
  for i in 0 to KERNEL_W-1 generate
    numerator(i)(j) <= '0' & data_in(i)(j);
    lpm_multX : lpm_mult
      GENERIC MAP (
        lpm_hint => "DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5",
        lpm_representation => "SIGNED",
        lpm_type => "LPM_MULT",
        lpm_widtha => NBITS_DATA+1,
        lpm_widthb => NBITS_KERNEL_DATA,
        lpm_widthp => NBITS_INTERNAL_RESULT
	)
      PORT MAP (
        dataa => numerator(i)(j),
        datab => kernel(i)(j),
        result => conv_result(i)(j)
	);
  end generate GEN_COLUMN_MULTIPLIERS;
end generate GEN_CONV_MULTIPLIERS;


add_proc: process (clk, rst_n) is

  variable result_tmp : std_logic_vector(NBITS_INTERNAL_RESULT-1 downto 0);

begin  -- process add_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    result_tmp := (others => '0');
    pxl_result_tmp <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    pxl_result_valid <= data_in_valid;
    result_tmp := (others => '0');
      for i in 0 to KERNEL_H-1 loop
        for j in 0 to KERNEL_W-1 loop
          result_tmp := result_tmp + conv_result(i)(j);
        end loop;
      end loop;

      -- Resultado somente parte inteira
      pxl_result_tmp <= result_tmp(NBITS_DATA + NBITS_KERNEL_FRAC downto NBITS_KERNEL_FRAC);

  end if;
  
end process add_proc;

pxl_result <= pxl_result_tmp(NBITS_DATA-1 downto 0) when pxl_result_tmp(NBITS_DATA) = '0'
              else (others => '1');


end architecture bhv;
