-- CALCULA MEDIA TEMPORAL DE UM DETERMINADO PIXEL
-- RECEBE UM VETOR DE PIXELS, DEVIDO AO PARALELISMO DO CORE
-- rodrigo.oliveira@thomson 20/07/16

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.lupa_library.all;

entity ac_media_temporal_calc is
  
  generic (
    N_BITS_PXL : integer := 8;
    PARALLELISM_LEVEL  : integer := 4;
    N_BITS_TW : integer := 13);

  port (
    clk, rst_n     : in std_logic;
    pxls_input     : in TypeArrayOfOutputDataOfFrameBuffer;
    start_sum      : in std_logic;   
    load_mean      : in std_logic;
    
    pxl_mean_out   : out std_logic_vector(N_BITS_DATA + N_BITS_FRAC-1 downto 0)
    );
end entity ac_media_temporal_calc;

architecture bhv of ac_media_temporal_calc is

  signal reg_input : unsigned(N_BITS_PXL*PARALLELISM_LEVEL-1 downto 0);
  signal sum_acc : unsigned(N_BITS_PXL+PARALLELISM_LEVEL+N_BITS_TW downto 0);
  signal reg_acc : unsigned(N_BITS_PXL+PARALLELISM_LEVEL+N_BITS_TW downto 0);
  
  
  --constant number_of_sums : integer := (2**N_BITS_TW/PARALLELISM_LEVEL); 
  type state_type is (st_idle, st_sum);
  signal state : state_type := st_idle;

  
  function generic_sum (input_array : TypeArrayOfOutputDataOfFrameBuffer;
                        n_bits_number : integer;
                        number_of_sums : integer)
    return unsigned is
    variable result: unsigned(n_bits_number+number_of_sums-1 downto 0) := (others => '0');
  begin
    for i in 0 to number_of_sums-1 loop
      result := result + unsigned(input_array(i));
    end loop;
    return result;
  end generic_sum;
  
  
  
begin

  acc_proc: process (clk, rst_n) is
  begin  -- process acc_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      sum_acc <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      case state is
        when st_idle =>
          sum_acc <= (others => '0');
          if start_sum = '1' then
            state <= st_sum;
          else
            state <= st_idle;
            reg_input <= (others => '0');
          end if;

        when st_sum =>         
          sum_acc <= sum_acc + generic_sum(pxls_input, N_BITS_PXL, PARALLELISM_LEVEL);     
          if load_mean = '1' then
            reg_acc <= sum_acc;
            state <= st_idle;
          else
            state <= st_sum;
            reg_acc <= reg_acc;
          end if;

      end case;             
    end if;
  end process acc_proc;


  pxl_mean_out <= compat_fixed_point(std_logic_vector(reg_acc srl N_BITS_TW),
                                     std_logic_vector(reg_acc(N_BITS_TW-1 downto 0)),
                                     N_BITS_FRAC,
                                     N_BITS_DATA + N_BITS_FRAC);

end bhv;

  
