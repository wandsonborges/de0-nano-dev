-- Unidade de MAC da AutoCorrecalao
-- Rodrigo Oliveira 14/03/16

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
  
LIBRARY lpm;
USE lpm.lpm_components.all;

entity ac_multiplier_acc_unit is
  
  generic (
    N_BITS_PXL_DATA            : integer := 8;
    N_BITS_ACC_TOTAL           : integer := 36;
    MULTIPLIER_PIPELINE_CYCLES : integer := 8;
    N_BITS_MULTIPLIER          : integer := 8);

  port (
    clk, rst_n                  : in  std_logic;
    en                          : in  std_logic;
    cs                          : in  std_logic;
    pxl_mean                    : in  std_logic_vector(N_BITS_PXL_DATA + N_BITS_FRAC-1 downto 0);   
    pxl_data_i                  : in  std_logic_vector(N_BITS_PXL_DATA + N_BITS_FRAC-1 downto 0);
    pxl_data_i_plus_j           : in  std_logic_vector(N_BITS_PXL_DATA + N_BITS_FRAC-1 downto 0);
    result                  	: out std_logic_vector(N_BITS_ACC_TOTAL-1 downto 0)
    );

end entity ac_multiplier_acc_unit;

architecture bhv of ac_multiplier_acc_unit is
  
  signal mult_result : std_logic_vector(2*N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
  signal reg_accumulator : signed(N_BITS_ACC_TOTAL-1 downto 0) := (others => '0');

  signal pxl_data_i_minus_mean : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0);
  signal pxl_data_i_plus_j_minus_mean : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0);
  
begin  -- architecture bhv

  lpm_mult_component : lpm.lpm_components.lpm_mult
	GENERIC MAP (
		lpm_hint => "DEDICATED_MULTIPLIER_CIRCUITRY=YES, MAXIMIZE_SPEED=5",
		lpm_pipeline => MULTIPLIER_PIPELINE_CYCLES,
		lpm_representation => "SIGNED",
		lpm_type => "LPM_MULT",
		lpm_widtha => N_BITS_MULTIPLIER,
		lpm_widthb => N_BITS_MULTIPLIER,
		lpm_widthp => 2*N_BITS_MULTIPLIER
	)
	PORT MAP (
                clock => clk,
                clken => en,
		dataa => pxl_data_i_minus_mean,
		datab => pxl_data_i_plus_j_minus_mean,
		result => mult_result
	);

	proc: process (clk, rst_n) is
  begin  -- process accum_process_clear
    if rst_n = '0' then                   -- asynchronous reset (active low)
--      result <= (others => '0');
      reg_accumulator <= (others => '0');
    elsif clk'event and clk = '1' then    -- rising clock edge
		if (cs = '1') then
--			result <= resize(unsigned(mult_result), N_BITS_ACC_TOTAL);
			reg_accumulator <= resize(signed(mult_result), N_BITS_ACC_TOTAL);
		else
--			result <= (others => '0');
			reg_accumulator <= (others => '0');
		end if;
	end if;
  end process proc;

  subtract_proc: process (clk, rst_n) is
  begin  -- process subtract_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pxl_data_i_plus_j_minus_mean <= (others => '0');
      pxl_data_i_minus_mean <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
        pxl_data_i_minus_mean <= std_logic_vector(signed('0' & pxl_data_i) - signed('0' & pxl_mean)); 
        pxl_data_i_plus_j_minus_mean <= std_logic_vector(signed('0' & pxl_data_i_plus_j) - signed('0' & pxl_mean));
    end if;
  end process subtract_proc;
  result <= std_logic_vector(reg_accumulator);
  
end architecture bhv;
