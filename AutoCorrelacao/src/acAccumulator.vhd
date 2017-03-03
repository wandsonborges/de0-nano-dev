--!@file acAccumulator.vhd
--!@author Rodrigo Oliveira 14/03/16
--!@brief Unidade de MAC da AutoCorrecalao
--!@image html doc/ac-data-path.png

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
  
LIBRARY lpm;
USE lpm.lpm_components.all;

--! @brief It implements the Accumulator block depicted in the image below.
--! @image html doc/ac-data-path.png

entity acAccumulator is
  
  generic (
    N_BITS_ACC_TOTAL           : integer := 36
	);
  port (
    clk, rst_n                  : in  std_logic;
    en                          : in  std_logic;
    multiplier_result           : in 	std_logic_vector(N_BITS_ACC_TOTAL-1 downto 0);
    clear_acc                   : in  std_logic;
    load_acc                    : in  std_logic;
    acc_result                  : out std_logic_vector(N_BITS_ACC_TOTAL-1 downto 0)
    );

end entity acAccumulator;

architecture bhv of acAccumulator is
  
  signal reg_accumulator : signed(N_BITS_ACC_TOTAL-1 downto 0) := (others => '0');
  signal reg_accumulator_out : signed(N_BITS_ACC_TOTAL-1 downto 0) := (others => '0');
  
begin  -- architecture bhv

	accum_process: process (clk, rst_n) is
  begin  -- process accum_process_clear
    if rst_n = '0' then                   -- asynchronous reset (active low)
      reg_accumulator <= (others => '0');
    elsif clk'event and clk = '1' then    -- rising clock edge
      if en = '1' then
        if clear_acc = '1' then
          reg_accumulator <= signed(multiplier_result);
        else
          reg_accumulator <= reg_accumulator + signed(multiplier_result);
        end if;
        if load_acc = '1' then
          reg_accumulator_out <= reg_accumulator;
        end if;
      else
        reg_accumulator_out <= reg_accumulator_out;
      end if;      
    end if;
  end process accum_process;


  --Output Signals
	acc_result <= std_logic_vector(reg_accumulator_out);

end bhv;	
