library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity lupa_fake is  
  generic (
    ROWS : integer := 480;
    COLS : integer := 640;
    FOT  : integer := 1200;
    ROT  : integer := 48
    );

  port (
    clk, rst_n  : in std_logic;
    en          : in std_logic;
    frame_valid : out std_logic;
    line_valid  : out std_logic;
    data_valid  : out std_logic;
    data_out    : out std_logic_vector(7 downto 0);
    startofpacket : out std_logic;
    endofpacket : out std_logic
    );
  
end entity lupa_fake;

architecture bhv of lupa_fake is

  signal FOT_counter : unsigned(10 downto 0) := (others => '0');
  signal ROT_counter : unsigned(5 downto 0) := (others => '0');
  signal line_counter : unsigned(9 downto 0) := (others => '0');
  signal col_counter : unsigned(10 downto 0) := (others => '0');

  signal data_out_s : unsigned(7 downto 0) := (others => '0');
  
  type state_type is (st_idle, st_fot, st_rot, st_valid_data);
  signal state : state_type := st_idle;
  
begin  -- architecture bhv

  proc: process (clk, rst_n) is
  begin  -- process proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      state <= st_idle;
      line_counter <= (others => '0');
      col_counter <= (others => '0');
      FOT_counter <= (others => '0');
      ROT_counter <= (others => '0');
      startofpacket <= '0';
      endofpacket <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if en = '1' or en = '0' then
        case state is
          when st_idle =>
            line_counter <= (others => '0');
            col_counter <= (others => '0');
            FOT_counter <= (others => '0');
            ROT_counter <= (others => '0');
            endofpacket <= '0';
            startofpacket <= '0';
            if en = '1' then
              state <= st_fot;
            else
              state <= st_idle;
            end if;

          when st_fot =>
            if FOT_counter = to_unsigned(FOT-1, FOT_counter'length) then
              state <= st_valid_data;
              startofpacket <= '1';
              FOT_counter <= (others => '0');
            else
              FOT_counter <= FOT_counter + 1;
              state <= st_fot;
            end if;

          when st_valid_data =>
            startofpacket <= '0';
            if line_counter = to_unsigned(ROWS-1, col_counter'length) and
            col_counter = to_unsigned(COLS-2, col_counter'length) then
              endofpacket <= '1';
            else
              endofpacket <= '0';
            end if;
           
        
            if col_counter = to_unsigned(COLS-1, col_counter'length) then
              state <= st_rot;
              col_counter <= (others => '0');            
            else
              col_counter <= col_counter + 1;
              state <= st_valid_data;
            end if;

          when st_rot =>
            if ROT_counter = to_unsigned(ROT-1, ROT_counter'length) then
              if line_counter = to_unsigned(ROWS-1, line_counter'length) then
                state <= st_idle;
                line_counter <= (others => '0');
              else
                state <= st_valid_data;
                line_counter <= line_counter + 1;
                ROT_counter <= (others => '0');
              end if;            
            else
              ROT_counter <= ROT_counter + 1;
              state <= st_rot;
            end if;                           
            
        end case;
      end if;      
    end if;
  end process proc;

  fake_data_proc: process (clk, rst_n) is
  begin  -- process fake_data_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      data_out_s <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (state = st_fot) then
        data_out_s <= (others => '0');
      elsif (state = st_valid_data) then -- and en = '1') then
        data_out_s <= data_out_s + 1;
      end if;
    end if;
  end process fake_data_proc;

  frame_valid <= '1' when state = st_valid_data or state = st_rot else '0';
  line_valid <= '1' when state = st_valid_data else '0';
  data_out <= std_logic_vector(data_out_s);
  data_valid <= '1' when state = st_valid_data else '0';
--  data_out <= std_logic_vector(line_counter(data_out'length-1 downto 0));
  

end architecture bhv;
