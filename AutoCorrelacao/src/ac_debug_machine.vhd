library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ac_debug_machine is
  
  port (
    clk, rst_n     : in  std_logic;
    data_sensor    : in  std_logic_vector(7 downto 0);
    ac_mux_sel     : in  std_logic;
    ac_write_start : in  std_logic;
    ac_write_en    : in  std_logic;
    probe_state    : in  std_logic_vector(7 downto 0);
    data_out       : out std_logic_vector(7 downto 0));

end entity ac_debug_machine;

architecture bhv of ac_debug_machine is

  type state_type is (st_nothing_happened, st_receive_mux_change, st_receive_write_start,
                 st_receive_write_en, st_everything_ok);
  
  signal state : state_type := st_nothing_happened;

  signal data_sigs : unsigned(7 downto 0) := (others => '0');

  signal counter_writes : unsigned(15 downto 0) := (others => '0');
begin  -- architecture bhv

 fsm_proc: process (clk, rst_n) is
 begin  -- process fsm_proc
   if rst_n = '0' then                  -- asynchronous reset (active low)
     state <= st_nothing_happened;
   elsif clk'event and clk = '1' then   -- rising clock edge
     case state is
       when st_nothing_happened =>
         if (ac_mux_sel = '1') then
           state <= st_receive_mux_change;
         else
           state <= st_nothing_happened;
         end if;

       when st_receive_mux_change =>
         if ac_write_start = '1' and ac_mux_sel = '1' then 
           state <= st_receive_write_start;
         else
           state <= st_receive_mux_change;
         end if;

       when st_receive_write_start =>
         if ac_write_en = '1' and ac_mux_sel = '1' then 
           state <= st_receive_write_en;
         else
           state <= st_receive_write_start;
         end if;

       when st_receive_write_en =>
         if counter_writes = 1023 then
           state <= st_everything_ok;
         else
           state <= st_receive_write_en;
         end if;

       when st_everything_ok =>
         state <= st_everything_ok;

     end case;
   end if;
 end process fsm_proc;

process (clk, rst_n) is
begin  -- process
  if rst_n = '0' then                   -- asynchronous reset (active low)
    counter_writes <= (others => '0');
  elsif clk'event and clk = '1' then    -- rising clock edge
    if ac_write_en = '1' and ac_mux_sel = '1' then
      counter_writes <= counter_writes + 1;
    else
      counter_writes <= counter_writes;
    end if;
  end if;
end process;
 data_sigs <= x"00" when state = st_nothing_happened
             else x"F0" when state = st_receive_mux_change
             else x"20" when state = st_receive_write_start
             else x"40" when state = st_receive_write_en
             else x"80" when state = st_everything_ok;

  data_out <= probe_state;  
end architecture bhv;
