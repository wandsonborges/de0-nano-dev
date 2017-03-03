-- Acumulador "Inteligente"
-- Pode requisitar pixels
-- Avisa quando terminou o somatorio
-- Rodrigo Oliveira 27/01/16

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity smart_accumulator is
  
  generic (
    N_BITS_COUNTER : integer := 8;
    N_BITS_INPUT   : integer := 8;
    N_BITS_OUTPUT  : integer := 16);

  port (
    clk, rst_n     : in std_logic;
    num_of_sums    : in std_logic_vector(N_BITS_COUNTER-1 downto 0);
    data_in        : in std_logic_vector(N_BITS_INPUT-1 downto 0);
    data_valid_in  : in std_logic;
    start_sum      : in std_logic; --inicia somatorio

    req_data       : out std_logic; --similar a sinal busy
    done           : out std_logic;
    data_out       : out std_logic_vector(N_BITS_OUTPUT-1 downto 0)
    );
end entity smart_accumulator;

architecture bhv of smart_accumulator is

  type state_type is (st_idle, st_sum, st_done);
  signal state : state_type := st_idle;
  
  signal result : unsigned(N_BITS_OUTPUT-1 downto 0) := (others => '0');
  signal counter : unsigned(N_BITS_COUNTER-1 downto 0) := (others => '0');

  signal reg_num_of_sums : unsigned(N_BITS_COUNTER-1 downto 0);
  signal reg_result : unsigned(N_BITS_OUTPUT-1 downto 0);
  signal reg_done : std_logic := '0';
  
begin  -- architecture bhv

proc: process (clk, rst_n) is
begin  -- process proc
  if rst_n = '0' then                   -- asynchronous reset (active low)
    reg_result <= (others => '0');
    state <= st_idle;
    reg_done <= '0';
    reg_num_of_sums <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    case state is
      when st_idle =>
        result <= (others => '0');
        counter <= (others => '0');
        if start_sum = '1' then
          state <= st_sum;
          reg_done <= '0';
          reg_num_of_sums <= unsigned(num_of_sums);
        else
          state <= st_idle;
        end if;

      when st_sum =>
        if counter = reg_num_of_sums then
          state <= st_done;
        elsif data_valid_in = '1' then
          result <= result + unsigned(data_in);
          counter <= counter + 1;
          state <= st_sum;
        else
          result <= result;
          counter <= counter;
          state <= st_sum;
        end if;

      when st_done =>
        reg_done <= '1';
        reg_result <= result;
        state <= st_idle;
    end case;
  end if;
end process proc;

data_out <= std_logic_vector(reg_result);
done <= reg_done;
req_data <= '1' when state = st_sum else '0';
  
end architecture bhv;

    
