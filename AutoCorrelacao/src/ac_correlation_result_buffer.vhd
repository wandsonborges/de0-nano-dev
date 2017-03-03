--Tradutor de enderecos para a RAM onde estará
--armazenado os frames do sensor LUPA
-- Rodrigo Oliveira
library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity ac_correlation_result_buffer is
  
  generic (
    FRAME_BUFFER_LATENCY : integer           := 2;
    N_BITS_INDEX        : integer            := 8;
    N_BITS_ACC_OUTPUT_TOTAL       : integer  := 8;
    N_BITS_PXL_CORR_RESULT_FRAC   : integer  := 8;
    NUM_OF_FRAMES       : integer := 1024;
    NUM_OF_REG_TO_BUF   : integer := 8;
    N_BITS_DATA         : integer            := 8;
    N_BITS_PXL_POSITION : integer            := 8;
    N_BITS_FRAME_INDEX  : integer            := 12;
    N_BITS_ADDR         : integer            := 16
    );

  port (
    clk, rst_n         : in  std_logic;
    index_j            : in std_logic_vector(N_BITS_INDEX-1 downto 0); --
    acc_corr_j         : in  std_logic;
    set_corr_j         : in  std_logic;
    pxl_correlation_in : in std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
    
    pxl_correlation_acc_output : out std_logic_vector(N_BITS_ACC_OUTPUT_TOTAL-1 downto 0)
    );
  

end entity ac_correlation_result_buffer;

architecture bhv of ac_correlation_result_buffer is

  signal set_mem : std_logic := '0';
  signal acc_mem : std_logic := '0';
  signal set_reg : std_logic := '0';
  signal acc_reg : std_logic := '0';

  signal count_cycles_fb : unsigned(2 downto 0) := (others => '0');
  
  signal index : std_logic_vector(N_BITS_INDEX-1 downto 0) := (others => '0');

  signal reg_current_correlation_result : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
  signal reg_old_correlation_result : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
  signal reg_new_correlation_result : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);
  signal reg_index_j : std_logic_vector(N_BITS_INDEX-1 downto 0) := (others => '0');
  signal addr_mem : std_logic_vector(N_BITS_TIME_WINDOW_TO_MEMORY-1 downto 0) := (others => '0');
  
  signal write_mem : std_logic := '0';
  signal mem_data_out : std_logic_vector(N_BITS_ACC_TOTAL -1 downto 0);

  signal index_out_of_range : std_logic := '0';

  signal pattern_data : unsigned(31 downto 0) := (others => '1');

   type state_type is (st_idle, st_wait_read_value, st_write_value, st_set_value, st_add_value);
  signal state : state_type := st_idle;
  
  type registersBuffer is array(NUM_OF_FRAMES-NUM_OF_REG_TO_BUF to NUM_OF_FRAMES-1) of
    std_logic_vector(N_BITS_ACC_TOTAL -1  downto 0);
  signal registers : registersBuffer;
  
begin  -- architecture bhv
  --RAM
	altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		indata_aclr_a => "NONE",
		intended_device_family => "Cyclone",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 2**N_BITS_TIME_WINDOW_TO_MEMORY,
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "CLOCK0",
		power_up_uninitialized => "FALSE",
		widthad_a => N_BITS_TIME_WINDOW_TO_MEMORY,
		width_a => N_BITS_ACC_TOTAL,
		width_byteena_a => 1,
		wrcontrol_aclr_a => "NONE"
	)
	PORT MAP (
		wren_a => write_mem,
		clock0 => clk,
		address_a => addr_mem,
		data_a => reg_new_correlation_result,
		q_a => mem_data_out
	);
	
--  altsyncram_component : altera_mf.altera_mf_components.altsyncram
--        GENERIC MAP (
--        	address_reg_b => "CLOCK0",
--        	clock_enable_input_a => "BYPASS",
--        	clock_enable_input_b => "BYPASS",
--        	clock_enable_output_a => "BYPASS",
--        	clock_enable_output_b => "BYPASS",
--        	indata_reg_b => "CLOCK0",
--        	intended_device_family => "Cyclone",
--        	lpm_type => "altsyncram",
--        	numwords_a => NUM_OF_FRAMES,
--        	operation_mode => "SINGLE_PORT",
--        	outdata_aclr_a => "NONE",
--        	outdata_reg_a => "CLOCK0",
--        	power_up_uninitialized => "FALSE",
--        	read_during_write_mode_mixed_ports => "DONT_CARE",
--        	widthad_a => N_BITS_INDEX,
--        	widthad_b => N_BITS_ADDR,
--        	width_a => N_BITS_PXL_CORR_RESULT_FRAC + N_BITS_PXL_CORR_RESULT_INT,
--        	width_byteena_a => 1
--        )
--        PORT MAP (
--        	clock0 => clk,
--        	wren_a => write_mem,
--        	address_a => reg_index_j,
--        	data_a => reg_new_correlation_result,
--        	q_a => mem_data_out
--                );

  fsm_proc: process (clk, rst_n) is
  begin  -- process fsm_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pattern_data <= (others => '1');
      reg_current_correlation_result <= (others => '0');
      reg_old_correlation_result <= (others => '0');
      reg_new_correlation_result <= (others => '0');
      state <= st_idle;
    elsif clk'event and clk = '1' then  -- rising clock edge
       case state is
      when st_idle =>
	    reg_index_j <= index_j;
      if set_mem = '1' then
        state <= st_set_value;
        reg_current_correlation_result <= pxl_correlation_in;
		reg_index_j <= std_logic_vector(unsigned(index_j) + 1);
      elsif acc_mem = '1' then
        state <= st_wait_read_value;
        reg_current_correlation_result <= pxl_correlation_in;
		reg_index_j <= std_logic_vector(unsigned(index_j) + 1);
      else
        state <= state;
        reg_current_correlation_result <= reg_current_correlation_result;
      end if;

    when st_set_value =>
      reg_new_correlation_result <= reg_current_correlation_result;
      state <= st_write_value;

    when st_wait_read_value =>
       if count_cycles_fb = to_unsigned(FRAME_BUFFER_LATENCY, count_cycles_fb'length) then
         state <= st_add_value;
         count_cycles_fb <= (others => '0');
       else
         count_cycles_fb <= count_cycles_fb + 1;
         state <= st_wait_read_value;
       end if;


    when st_add_value =>
      reg_new_correlation_result <= std_logic_vector(signed(mem_data_out) +
                                                     signed(reg_current_correlation_result));
      state <= st_write_value;

    when st_write_value =>
      pattern_data <= pattern_data - x"04030201";
      state <= st_idle;     

  end case;
    end if;
  end process fsm_proc;
 
  
      
  write_reg_proc: process (clk, rst_n) is
  begin  -- process write_reg_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      registers <= (others => (others => '0'));
    elsif clk'event and clk = '1' then  -- rising clock edge
      if set_reg = '1' then
        --registers(to_integer(signed(index))) <= pxl_correlation_in;
      elsif acc_reg = '1' then
        --registers(to_integer(signed(index))) <= std_logic_vector(signed(registers(to_integer(signed(index)))) + signed(pxl_correlation_in));
      else
        registers <= registers;
      end if;      
    end if;
  end process write_reg_proc;

--  index_out_of_range <= '0' when signed(index_j(N_BITS_INDEX-1 downto N_BITS_TIME_WINDOW_TO_MEMORY)) = 0
--                        else '1';
        
  write_mem <= '1' when (state = st_write_value) and unsigned(reg_index_j) < (2**N_BITS_TIME_WINDOW_TO_MEMORY)-1  else '0';
  
  index <= index_j;
  
  set_mem <= '1' when (unsigned(index) < (NUM_OF_FRAMES-NUM_OF_REG_TO_BUF)) and
             set_corr_j = '1' else '0';

  set_reg <= '1' when (unsigned(index) >= (NUM_OF_FRAMES-NUM_OF_REG_TO_BUF)) and
               set_corr_j = '1' else '0';

  acc_mem <= '1' when (unsigned(index) < (NUM_OF_FRAMES-NUM_OF_REG_TO_BUF)) and
             acc_corr_j = '1' else '0';

  acc_reg <= '1' when (unsigned(index) >= (NUM_OF_FRAMES-NUM_OF_REG_TO_BUF)) and
               acc_corr_j = '1' else '0';
  

  addr_mem <= reg_index_j(N_BITS_TIME_WINDOW_TO_MEMORY-1 downto 0);	
  pxl_correlation_acc_output <= mem_data_out(N_BITS_ACC_TOTAL-1 downto N_BITS_ACC_TOTAL - N_BITS_ACC_OUTPUT_TOTAL);
																		


end architecture bhv;
