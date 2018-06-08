library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.conv_package.all;

LIBRARY lpm;
USE lpm.lpm_components.all;


entity window_gen is
  
  generic (
    COLS : integer := 640;
    LINES : integer := 480;
    NBITS_COLS : integer := 12;
    NBITS_LINES : integer := 12
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
    start_conv : in std_logic;
    pxl_valid : in std_logic;
    pxl_data : in STD_LOGIC_VECTOR(NBITS_DATA-1 downto 0);
    window_valid : out std_logic;
    window_data : out window_type
    );               

end entity window_gen;

architecture bhv of window_gen is


  signal col_counter : unsigned(NBITS_COLS-1 downto 0) := (others => '0');
  signal line_counter : unsigned(NBITS_LINES-1 downto 0) := (others => '0');

  signal index_firstLine, index_secondLine, index_thirdLine : unsigned(3 downto 0) := (others => '0');
  
  type line_type is array (0 to COLS-1) of STD_LOGIC_VECTOR(NBITS_DATA-1 downto 0);
  type lines_type is array(0 to KERNEL_H-1) of line_type;
  signal img_lines : lines_type := (others => (others => (others => '0')));

  type wg_state_type is (st_idle, st_gettingFirstLine, st_gettingSecondLine, st_gettingLines, st_finish);
  signal wg_state : wg_state_type := st_idle;

  signal window_data_reg : window_type := (others => (others => (others => '0')));

begin

  data_proc: process (clk, rst_n) is
  begin  -- process data_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      col_counter <= (others => '0');
      line_counter <= (others => '0');
      index_firstLine <= x"0";
      index_secondLine <= x"1";
      index_thirdLine <= x"2";
      img_lines => (others => (others => (others => '0')));
      
      wg_state <= st_idle;      
    elsif clk'event and clk = '1' then  -- rising clock edge
      case wg_state is
        
        when st_idle =>
          col_counter <= (others => '0');
          line_counter <= (others => '0');          
          if (start_conv = '1') then
            wg_state <= st_gettingFirstLine;
          else
            wg_state <= st_idle;
          end if;

        when st_gettingFirstLine =>
          if (pxl_valid = '1') then
            img_lines(to_integer(index_firstLine))(to_integer(col_counter)) <= pxl_data;
            if (col_counter = COLS-1) then
              wg_state <= st_gettingSecondLine;
              line_counter <= line_counter + 1;
              col_counter <= (others => '0');
            else
              col_counter <= col_counter + 1;
              line_counter <= line_counter;
              wg_state <= st_gettingFirstLine;
            end if;
          else
            first_line <= first_line;
            col_counter <= col_counter;
            line_counter <= col_counter;
          end if;


        when st_gettingSecondLine =>
          if (pxl_valid = '1') then
            img_lines(to_integer(index_secondLine))(to_integer(col_counter)) <= pxl_data;
            if (col_counter = COLS-1) then
              wg_state <= st_gettingLines;
              line_counter <= line_counter + 1;
              col_counter <= (others => '0');
            else
              col_counter <= col_counter + 1;
              line_counter <= line_counter;
              wg_state <= st_gettingSecondLine;
            end if;
          else
            second_line <= second_line;
            col_counter <= col_counter;
            line_counter <= col_counter;
          end if;

        when st_gettingLines =>
          if (pxl_valid = '1') then
            img_lines(to_integer(index_thirdLine))(to_integer(col_counter)) <= pxl_data;
            if (line_counter = LINES-1 and col_counter = COLS-1) then
              wg_state <= st_finish;
              line_counter <= (others => '0');
              col_counter <= (others => '0');
            elsif (col_counter = COLS-1) then
              wg_state <= st_gettingLines;
              line_counter <= line_counter + 1;
              col_counter <= (others => '0');
              if(index_firstLine = KERNEL_H-1) then
                index_firstLine <= x"0";
              else
                index_firstLine <= index_firstLine + 1;
              end if;

              if(index_secondLine = KERNEL_H-1) then
                index_secondLine <= x"0";
              else
                index_secondLine <= index_secondLine + 1;
              end if;

              if(index_thirdLine = KERNEL_H-1) then
                index_thirdLine <= x"0";
              else
                index_thirdLine <= index_thirdLine + 1;
              end if;
                              
              img_lines(to_integer(index_secondLine))(COLS-1) <= pxl_data;
            else
              wg_state <= st_gettingLines;
              col_counter <= col_counter + 1;
              line_counter <= line_counter;
            end if;
          else
            wg_state <= st_gettingLines;
            line_counter <= line_counter;
            col_counter <= col_counter;
            third_line <= third_line;
          end if;

          when st_finish =>
            wg_state <= st_idle;

      end case;
      
    end if;
  end process data_proc;

 

  win_proc: process (clk, rst_n) is
  begin  -- process win_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      window_valid <= '0';
      window_data_reg <= (others => (others => (others => '0')));
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (pxl_valid = '1' and col_counter > KERNEL_W-2 and line_counter > KERNEL_H-2) then
        window_valid <= '1';
        window_data_reg(0)(0) <= img_lines(to_integer(index_firstLine))(to_integer(col_counter)-2);
        window_data_reg(0)(1) <= img_lines(to_integer(index_firstLine))(to_integer(col_counter)-1);
        window_data_reg(0)(2) <= img_lines(to_integer(index_firstLine))(to_integer(col_counter));

        window_data_reg(1)(0) <= img_lines(to_integer(index_secondLine))(to_integer(col_counter)-2);
        window_data_reg(1)(1) <= img_lines(to_integer(index_secondLine))(to_integer(col_counter)-1);
        window_data_reg(1)(2) <= img_lines(to_integer(index_secondLine))(to_integer(col_counter));

        window_data_reg(2)(0) <= img_lines(to_integer(index_thirdLine))(to_integer(col_counter)-2);
        window_data_reg(2)(1) <= img_lines(to_integer(index_thirdLine))(to_integer(col_counter)-1);
        window_data_reg(2)(2) <= pxl_data;
      else
        window_valid <= '0';
        window_data_reg <= window_data_reg;
        
      end if;
      

      
    end if;
  end process win_proc;

    window_data <= window_data_reg;
  
end architecture bhv;
