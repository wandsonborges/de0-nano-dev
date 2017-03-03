--! @brief Nucleo do Algoritmo de AutoCorrelacao
--! @author Rodrigo Oliveira 29/01/16

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
  
LIBRARY lpm;
USE lpm.lpm_components.all;

--! @brief Nucleo do Algoritmo de AutoCorrelacao
--!
--! Controla o core da Auto Correlacao.
--!
--! Layout: https://drive.google.com/file/d/0Byb2W7YgjSLwODlDelprT2FnV3c/view?usp=sharing
--!
--! \image html doc/core-of-the-autocorrelation.png
entity ac_core_unit is
  
  generic (
    PURE_FIXED_POINT_FRAC_BITS    : integer := 0; 
    MULTIPLIER_PIPELINE_CYCLES    : integer := 8;
    N_BITS_MULTIPLIER             : integer := 32;
    N_BITS_PXL_CORR_RESULT_INT    : integer := 16;
    N_BITS_PXL_CORR_RESULT_FRAC   : integer := 16;
    N_BITS_SIZE_OF_WINDOW         : integer := 16;
    N_BITS_INDEX                  : integer := 8;
    N_BITS_PXL_DATA               : integer := 8;
    N_BITS_MEDIA_TEMP_SQR_INT     : integer := 16;
    N_BITS_MEDIA_TEMP_SQR_FRAC    : integer := 16;
    N_BITS_MEDIA_TEMP_SQR_WJ_INT  : integer := 16;
    N_BITS_MEDIA_TEMP_SQR_WJ_FRAC : integer := 16;    
    N_BITS_MEDIA_TEMP_INT         : integer := 16;
    N_BITS_MEDIA_TEMP_FRAC        : integer := 16);

  port (
    clk, rst_n                   : in std_logic;
    window_size                  : in std_logic_vector(N_BITS_SIZE_OF_WINDOW-1 downto 0);
    index_j                      : in std_logic_vector(N_BITS_INDEX-1 downto 0);
    pxl_mean_square              : in std_logic_vector(N_BITS_MEDIA_TEMP_SQR_INT + N_BITS_MEDIA_TEMP_SQR_FRAC -1 downto 0);
    pxl_mean                     : in std_logic_vector(N_BITS_MEDIA_TEMP_INT + N_BITS_MEDIA_TEMP_FRAC -1 downto 0);
    pxl_data_i                   : in std_logic_vector(N_BITS_PXL_DATA-1 downto 0);
    pxl_data_j                   : in std_logic_vector(N_BITS_PXL_DATA-1 downto 0);
    pxls_valid_in                : in std_logic;
    start_mean_sqr_calc          : in std_logic;
    start_mean_sqr_times_W_calc  : in std_logic;
    subtract_mean_sqr_W          : in std_logic;
    clear_acc                    : in std_logic;
    load_acc                     : in std_logic;
    
    mean_sqr_output              : out std_logic_vector(N_BITS_MEDIA_TEMP_SQR_INT + N_BITS_MEDIA_TEMP_SQR_FRAC -1 downto 0);
    mean_sqr_times_wj_output     : out std_logic_vector(N_BITS_MEDIA_TEMP_SQR_WJ_INT + N_BITS_MEDIA_TEMP_SQR_WJ_FRAC -1 downto 0);
    accumulator_output           : out std_logic_vector(N_BITS_PXL_CORR_RESULT_INT + N_BITS_PXL_CORR_RESULT_FRAC -1 downto 0);
    multiplier_done              : out std_logic);

end entity ac_core_unit;

architecture bhv of ac_core_unit is
 
 type state_type is (st_start, st_idle, st_calc_mean_sqr, st_calc_mean_sqr_times_wj,
                      st_wait_multiplication_done, st_reg_result, st_done);
 signal state : state_type := st_idle;

 signal const_mult_a : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal const_mult_b : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal pxl_ac_mult_a : std_logic_vector(N_BITS_MEAN_TOTAL-1 downto 0) := (others => '0');
 signal pxl_ac_mult_b : std_logic_vector(N_BITS_MEAN_TOTAL-1 downto 0) := (others => '0');
 signal mult_in_a : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal mult_in_b : std_logic_vector(N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal const_mult_result : std_logic_vector(2*N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal mult_result : std_logic_vector(2*N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal mult_result_to_acc : std_logic_vector(N_BITS_PXL_CORR_RESULT_FRAC+N_BITS_PXL_CORR_RESULT_INT-1 downto 0) := (others => '0');


 signal reg_accumulator : signed(2*N_BITS_MULTIPLIER-1 downto 0) := (others => '0');
 signal reg_accumulator_out : std_logic_vector(2*N_BITS_MULTIPLIER-1 downto 0) := (others => '0');


 signal multiplication_cycles : unsigned(7 downto 0) := (others => '0');


 signal flag_const_mult : std_logic := '0'; -- 0: media*media
                                            -- 1: media*media*(W)

 signal sgn_mean_sqr_times_w_output  : std_logic_vector(N_BITS_MEDIA_TEMP_SQR_WJ_INT + N_BITS_MEDIA_TEMP_SQR_WJ_FRAC -1 downto 0);
 signal mean_sqr_times_wj  : std_logic_vector(N_BITS_MEDIA_TEMP_SQR_WJ_INT + N_BITS_MEDIA_TEMP_SQR_WJ_FRAC -1 downto 0);

begin  -- architecture bhv

  -- Multiplicador do Core
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
		dataa => mult_in_a,
		datab => mult_in_b,
		result => mult_result
	);


fsm_proc: process (clk, rst_n) is
begin  -- process fsm_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    state <= st_start;
    const_mult_a <= (others => '0');
    const_mult_b <= (others => '0');
    mean_sqr_output <= (others => '0');
    sgn_mean_sqr_times_w_output <= (others => '0');
    
  elsif clk'event and clk = '1' then    -- rising clock edge
    case state is
      when st_start =>
        sgn_mean_sqr_times_w_output <= (others => '0');
        if start_mean_sqr_calc = '1' then
          state <= st_calc_mean_sqr;
        elsif start_mean_sqr_times_W_calc = '1' then
          state <= st_calc_mean_sqr_times_wj;
        else
          state <= st_start;
        end if;

      when st_idle =>
        if start_mean_sqr_calc = '1' then
          state <= st_calc_mean_sqr;
        elsif start_mean_sqr_times_W_calc = '1' then
          state <= st_calc_mean_sqr_times_wj;
        else         
          state <= st_idle;
        end if;

        -- Calculo da media ao quadrado => media*media
      when st_calc_mean_sqr =>
        flag_const_mult <= '0';
        const_mult_a <= compat_fixed_point(pxl_mean(N_BITS_MEDIA_TEMP_INT-1 + N_BITS_MEDIA_TEMP_FRAC
                                                    downto N_BITS_MEDIA_TEMP_FRAC),
                                         pxl_mean(N_BITS_MEDIA_TEMP_FRAC-1 downto 0),
                                         N_BITS_MEDIA_TEMP_FRAC, N_BITS_MULTIPLIER);

        const_mult_b <= compat_fixed_point(pxl_mean(N_BITS_MEDIA_TEMP_INT-1 + N_BITS_MEDIA_TEMP_FRAC
                                                    downto N_BITS_MEDIA_TEMP_FRAC),
                                         pxl_mean(N_BITS_MEDIA_TEMP_FRAC-1 downto 0),
                                         N_BITS_MEDIA_TEMP_FRAC, N_BITS_MULTIPLIER);
        state <= st_wait_multiplication_done;

        -- Calculo da (media ao quadrado) * Numero de amostras => p^2 * (W-j)
      when st_calc_mean_sqr_times_wj =>
        flag_const_mult <= '1';
        const_mult_a <= compat_fixed_point(pxl_mean_square(N_BITS_MEDIA_TEMP_SQR_INT-1 + N_BITS_MEDIA_TEMP_SQR_FRAC
                                                           downto N_BITS_MEDIA_TEMP_SQR_FRAC),
                                         pxl_mean_square(N_BITS_MEDIA_TEMP_SQR_FRAC-1 downto 0),
                                         N_BITS_MEDIA_TEMP_SQR_FRAC, N_BITS_MULTIPLIER);

        --const_mult_b <= compat_fixed_point(window_size, "", PURE_FIXED_POINT_FRAC_BITS, N_BITS_MULTIPLIER);
        const_mult_b <= std_logic_vector(resize(unsigned(window_size), N_BITS_MULTIPLIER));
        state <= st_wait_multiplication_done;

        -- Multiplicacao Terminou
      when st_wait_multiplication_done =>
        if multiplication_cycles = to_unsigned(MULTIPLIER_PIPELINE_CYCLES-1, multiplication_cycles'length) then
          multiplication_cycles <= (others => '0');
          state <= st_reg_result;
          else
          multiplication_cycles <= multiplication_cycles + 1;
          state <= st_wait_multiplication_done;
        end if;

      when st_reg_result =>
          -- Multiplicacao duplica numero de bits. Pegar bits do centro do vetor.
          -- Resultado 2*N.2*M  --> Pegar N(N.M)M
        if flag_const_mult = '0' then
            mean_sqr_output <= compat_fixed_point(mult_result(2*N_BITS_MEDIA_TEMP_INT-1 + 2*N_BITS_MEDIA_TEMP_FRAC
                                                  downto 2*N_BITS_MEDIA_TEMP_FRAC),
                                      mult_result(2*N_BITS_MEDIA_TEMP_FRAC-1 downto 0),
                                      N_BITS_MEDIA_TEMP_SQR_FRAC,
                                                  N_BITS_MEDIA_TEMP_SQR_INT + N_BITS_MEDIA_TEMP_SQR_FRAC);
          else
            sgn_mean_sqr_times_w_output <= compat_fixed_point(mult_result(mult_result'length-1
                                                          downto N_BITS_MEDIA_TEMP_SQR_FRAC + PURE_FIXED_POINT_FRAC_BITS),
                                              mult_result(N_BITS_MEDIA_TEMP_FRAC + PURE_FIXED_POINT_FRAC_BITS -1
                                                          downto 0),
                                              N_BITS_MEDIA_TEMP_SQR_WJ_FRAC,
                                                           N_BITS_MEDIA_TEMP_SQR_WJ_INT + N_BITS_MEDIA_TEMP_SQR_WJ_FRAC);
          end if;
            state <= st_done;
      when st_done =>
        state <= st_idle;
    end case;            
        
  end if;
end process fsm_proc;



w_minus_j_process: process (clk, rst_n) is
begin  -- process w_minus_j_process_clear
  if rst_n = '0' then                   -- asynchronous reset (active low)
    mean_sqr_times_wj <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    if state = st_done and flag_const_mult = '1' then
      mean_sqr_times_wj <= sgn_mean_sqr_times_w_output;
    elsif subtract_mean_sqr_W = '1' then
      mean_sqr_times_wj <= std_logic_vector(unsigned(mean_sqr_times_wj) - unsigned(
        compat_fixed_point(pxl_mean_square(N_BITS_MEDIA_TEMP_SQR_INT + N_BITS_MEDIA_TEMP_SQR_FRAC-1
                                           downto N_BITS_MEDIA_TEMP_SQR_FRAC),
                           pxl_mean_square(N_BITS_MEDIA_TEMP_SQR_FRAC-1 downto 0),
                           N_BITS_MEDIA_TEMP_SQR_WJ_FRAC,
                           N_BITS_MEDIA_TEMP_SQR_WJ_FRAC + N_BITS_MEDIA_TEMP_SQR_WJ_INT)));
                                           
    else
      mean_sqr_times_wj <= mean_sqr_times_wj;
    end if;
  end if;
end process w_minus_j_process;


accum_process: process (clk, rst_n) is
begin  -- process accum_process_clear
  if rst_n = '0' then                   -- asynchronous reset (active low)
    reg_accumulator <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    if clear_acc = '1' then
      reg_accumulator <= signed(mult_result);
    elsif pxls_valid_in = '1' then
      reg_accumulator <= reg_accumulator + signed(mult_result);
    else
      reg_accumulator <= reg_accumulator;
    end if;
    if load_acc = '1' then
      -- Ajustes de ponto fixo pós saída do multiplicador.
      -- Multiplicador aumenta qtd de bits fracionarios
      reg_accumulator_out <= std_logic_vector(reg_accumulator);
    else
      reg_accumulator_out <= reg_accumulator_out;
    end if;   
  end if;
end process accum_process;


--p2*(w-j)
mean_sqr_times_wj_output <= mean_sqr_times_wj;

-- Pi - Pmedia
pxl_ac_mult_a <= compat_fixed_point(pxl_data_i, "", N_BITS_MEDIA_TEMP_FRAC,
                                    N_BITS_MEDIA_TEMP_INT + N_BITS_MEDIA_TEMP_FRAC) - pxl_mean;
-- Pi+j - Pmedia
pxl_ac_mult_b <= compat_fixed_point(pxl_data_j, "", N_BITS_MEDIA_TEMP_FRAC,
                                    N_BITS_MEDIA_TEMP_INT + N_BITS_MEDIA_TEMP_FRAC) - pxl_mean;


-- Deixa pipeline livre para auto-correlacao, exceto se tiver que calcular as constantes.                 
mult_in_a <= const_mult_a when (state = st_calc_mean_sqr_times_wj or
                              state = st_calc_mean_sqr or
                              state = st_wait_multiplication_done or
                              state = st_reg_result or  
                              state = st_done) else std_logic_vector(resize(signed(pxl_ac_mult_a),N_BITS_MULTIPLIER));

mult_in_b <= const_mult_b when (state = st_calc_mean_sqr_times_wj or
                              state = st_calc_mean_sqr or
                              state = st_wait_multiplication_done or
                              state = st_reg_result or  
                              state = st_done) else std_logic_vector(resize(signed(pxl_ac_mult_b),N_BITS_MULTIPLIER));

multiplier_done <= '1' when (state = st_start or state = st_idle) else '0';

accumulator_output <= reg_accumulator_out(N_BITS_ACC_OUTPUT_TOTAL-1 downto 0);






end architecture bhv;
