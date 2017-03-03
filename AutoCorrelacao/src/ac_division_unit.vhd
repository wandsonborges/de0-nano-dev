--! @brief Unidade de Divisão
--! @author Rodrigo Oliveira 27/01/16

library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
  
LIBRARY lpm;
USE lpm.lpm_components.all;

--! @brief Unidade de Divisão
--!
--! Controla o divisor da Auto Correlacao.
--!
--! Layout: https://drive.google.com/file/d/0Byb2W7YgjSLwbnBPcXZaYkZGWVk/view?usp=sharing
--!
--! @image html doc/division-unit.png
entity ac_division_unit is
  
  generic (
    PURE_FIXED_POINT_FRAC_BITS    : integer := 0;
    DIVIDER_PIPELINE_CYCLES       : integer := 8;
    N_BITS_ACC_OUTPUT_INT         : integer := 16;
    N_BITS_ACC_OUTPUT_FRAC        : integer := 16;
    N_BITS_DIVIDER_NUM            : integer := 64;
    N_BITS_DIVIDER_DEN            : integer := 64;
    N_BITS_PXL_CORR_RESULT_INT    : integer := 18;
    N_BITS_PXL_CORR_RESULT_FRAC   : integer := 14;
    N_BITS_WINDOW_OF_FRAMES       : integer := 18;
    N_BITS_PXL_DATA               : integer := 8;
    N_BITS_MEDIA_TEMP_SQR_INT     : integer := 18;
    N_BITS_MEDIA_TEMP_SQR_FRAC    : integer := 14;
    N_BITS_MEDIA_TEMP_SQR_W_INT   : integer := 18;
    N_BITS_MEDIA_TEMP_SQR_W_FRAC  : integer := 14;
    N_BITS_MEDIA_TEMP_INT         : integer := 18;
    N_BITS_MEDIA_TEMP_FRAC        : integer := 14);

  port (
    clk, rst_n                  : in std_logic;
    window_of_frames            : in std_logic_vector(N_BITS_WINDOW_OF_FRAMES-1 downto 0);
    pxl_correlation_acc_result  : in std_logic_vector(N_BITS_ACC_OUTPUT_FRAC+N_BITS_ACC_OUTPUT_INT-1 downto 0);
    pxl_mean_square_times_wj    : in std_logic_vector(N_BITS_MEDIA_TEMP_SQR_W_INT + N_BITS_MEDIA_TEMP_SQR_W_FRAC -1 downto 0);
    pxl_data                    : in std_logic_vector(N_BITS_PXL_DATA-1 downto 0);
    pxl_valid_in                : in std_logic;
    start_mean_calc             : in std_logic;
    start_frame_correation_calc : in std_logic;

    pxl_temp_mean_output        : out std_logic_vector(N_BITS_MEDIA_TEMP_FRAC + N_BITS_MEDIA_TEMP_INT-1 downto 0);
    pxl_correlation_output      : out std_logic_vector(N_BITS_PXL_CORR_RESULT_FRAC + N_BITS_PXL_CORR_RESULT_INT -1 downto 0);
    divider_output              : out std_logic_vector(N_BITS_DIVIDER_NUM -1 downto 0);
    req_pxl_to_sum              : out std_logic;
    divider_done                : out std_logic);

end entity ac_division_unit;

architecture bhv of ac_division_unit is

  constant N_BITS_RESULT_SUM : integer := N_BITS_DIVIDER_NUM;
 
  type state_type is (st_start, st_idle, st_calc_sum, st_wait_sum_done, st_calc_frame_corr,
                      st_wait_division_done, st_reg_result, st_done);
  signal state : state_type := st_idle;

  signal req_data      : std_logic;
  signal sum_done      : std_logic;
  signal sum_output    : std_logic_vector(N_BITS_RESULT_SUM-1 downto 0);

  signal reg_numer     : std_logic_vector(N_BITS_DIVIDER_NUM-1 downto 0);
  signal reg_denom     : std_logic_vector(N_BITS_DIVIDER_DEN-1 downto 0);
  signal division_done : std_logic := '0';
  signal division_cycles : unsigned(7 downto 0) := (others => '0');
  signal s_divider_output : std_logic_vector(N_BITS_DIVIDER_NUM-1 downto 0) := (others => '0');

  signal flag_op_div : std_logic := '0'; --0: calc_media
                                         --1: calc pxl_corr


begin  -- architecture bhv


smart_accumulator_1: entity work.smart_accumulator
  generic map (
    N_BITS_COUNTER => N_BITS_WINDOW_OF_FRAMES,
    N_BITS_INPUT   => N_BITS_PXL_DATA,
    N_BITS_OUTPUT  => N_BITS_RESULT_SUM)
  port map (
    clk           => clk,
    rst_n         => rst_n,
    num_of_sums   => window_of_frames,
    data_in       => pxl_data,
    data_valid_in => pxl_valid_in,
    start_sum     => start_mean_calc,
    req_data      => req_data,
    done          => sum_done,
    data_out      => sum_output);

dFfSynchronizer_1: entity work.dFfSynchronizer
  generic map (
    SYNCHRONIZATION_STAGES => DIVIDER_PIPELINE_CYCLES)
  port map (
    clock  => clk,
    nReset => rst_n,
    input  => sum_done,
    output => division_done);

--Divisor de Ponto Fixo
-- numero de bits_frac do numerador - numero de bits_frac denominador
-- = numero bits_frac do resultado!
divisor1 : lpm.lpm_components.lpm_divide
    generic map(
      lpm_widthd          => N_BITS_DIVIDER_NUM,
      lpm_pipeline        => DIVIDER_PIPELINE_CYCLES,
      lpm_hint            => "MAXIMIZE_SPEED=7, LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_drepresentation => "SIGNED",
      lpm_widthn          => N_BITS_DIVIDER_DEN)
    port map(
      clock    => clk,
      clken    => '1',
      numer    => std_logic_vector(reg_numer),
      denom    => std_logic_vector(reg_denom),
      quotient => s_divider_output
      );
  
fsm_proc: process (clk, rst_n) is
begin  -- process fsm_proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    state <= st_start;
    reg_numer <= (others => '0');
    reg_denom <= std_logic_vector(to_unsigned(1, reg_denom'length));
    division_cycles <= (others => '0');
    pxl_temp_mean_output <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    case state is
      when st_start =>
        reg_numer <= std_logic_vector(shift_left(resize(signed(pxl_correlation_acc_result),N_BITS_DIVIDER_NUM),
                                                 N_BITS_DIVIDER_NUM-N_BITS_ACC_OUTPUT_TOTAL));
        
        reg_denom <= compat_fixed_point(pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_INT-1 +
                                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC downto N_BITS_MEDIA_TEMP_SQR_W_FRAC),
                                        pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_FRAC-1 downto 0),
                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC, N_BITS_DIVIDER_DEN);
        if start_mean_calc = '1' then
          state <= st_calc_sum;
        elsif start_frame_correation_calc = '1' then
          state <= st_calc_frame_corr;
        else
          state <= st_start;
        end if;
        
      when st_idle =>
        reg_numer <= std_logic_vector(shift_left(resize(signed(pxl_correlation_acc_result),N_BITS_DIVIDER_DEN),
                                                 N_BITS_DIVIDER_NUM-N_BITS_ACC_OUTPUT_TOTAL));
        
        reg_denom <= compat_fixed_point(pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_INT-1 +
                                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC downto N_BITS_MEDIA_TEMP_SQR_W_FRAC),
                                        pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_FRAC-1 downto 0),
                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC, N_BITS_DIVIDER_DEN);
                
        if start_mean_calc = '1' then
          state <= st_calc_sum;
        elsif start_frame_correation_calc = '1' then
          state <= st_calc_frame_corr;
        else
          state <= st_idle;
        end if;

      when st_calc_sum =>
        state <= st_wait_sum_done;

      when st_wait_sum_done =>
        if sum_done = '1' then
          state <= st_wait_division_done;
          reg_numer <= compat_fixed_point(sum_output, "", PURE_FIXED_POINT_FRAC_BITS + N_BITS_MEDIA_TEMP_FRAC, N_BITS_DIVIDER_NUM);
          --reg_denom <= compat_fixed_point(window_of_frames, "", PURE_FIXED_POINT_FRAC_BITS, N_BITS_DIVIDER_DEN);
          reg_denom <= std_logic_vector(resize(unsigned(window_of_frames), N_BITS_DIVIDER_DEN));
			
        else
          reg_numer <= reg_numer;
          reg_denom <= reg_denom;
          state <= st_wait_sum_done;
        end if;

      when st_calc_frame_corr =>
        state <= st_wait_division_done;
        reg_numer <= compat_fixed_point(pxl_correlation_acc_result(N_BITS_ACC_OUTPUT_INT-1 +
                                                               N_BITS_ACC_OUTPUT_FRAC downto N_BITS_ACC_OUTPUT_FRAC),
                                        pxl_correlation_acc_result(N_BITS_ACC_OUTPUT_FRAC-1 downto 0),
                                        N_BITS_MEDIA_TEMP_SQR_FRAC + N_BITS_PXL_CORR_RESULT_FRAC, N_BITS_DIVIDER_NUM);
        
        reg_denom <= compat_fixed_point(pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_INT-1 +
                                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC downto N_BITS_MEDIA_TEMP_SQR_W_FRAC),
                                        pxl_mean_square_times_wj(N_BITS_MEDIA_TEMP_SQR_W_FRAC-1 downto 0),
                                        N_BITS_MEDIA_TEMP_SQR_W_FRAC, N_BITS_DIVIDER_DEN);
        
      when st_wait_division_done =>
        if division_cycles = to_unsigned(DIVIDER_PIPELINE_CYCLES-1, division_cycles'length) then      
          division_cycles <= (others => '0');
          state <= st_reg_result;
        else
          division_cycles <= division_cycles + 1;
          state <= st_wait_division_done;
        end if;

      when st_reg_result =>
        if flag_op_div = '0' then
            pxl_temp_mean_output <= s_divider_output(N_BITS_MEDIA_TEMP_FRAC+N_BITS_MEDIA_TEMP_INT-1 downto 0);
        end if;
        state <= st_done;
      when st_done =>    
        state <= st_idle;
    end case;            
        
  end if;
end process fsm_proc;
pxl_correlation_output <= s_divider_output(N_BITS_PXL_CORR_RESULT_FRAC+N_BITS_PXL_CORR_RESULT_INT-1 downto 0);

divider_done <= '1' when (state = st_idle or state = st_done) else '0';
divider_output <= s_divider_output;
req_pxl_to_sum <= req_data;


end architecture bhv;
