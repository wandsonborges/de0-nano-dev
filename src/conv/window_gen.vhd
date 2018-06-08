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


  signal col_counter, col_counter_f : unsigned(NBITS_COLS-1 downto 0) := (others => '0');
  signal line_counter, line_counter_f : unsigned(NBITS_LINES-1 downto 0) := (others => '0');

  signal index_firstLine, index_secondLine, index_thirdLine, index_thirdLine_f, index_thirdLine_ff : unsigned(3 downto 0) := (others => '0');

  type line_mem_type is array (0  to COLS-1) of STD_LOGIC_VECTOR(NBITS_DATA-1 downto 0);
  signal line_mem0, line_mem1, line_mem2 : line_mem_type := (others => (others => '0'));

  signal mem0_f, mem0_ff, mem0_fff, mem1_f, mem1_ff, mem1_fff, mem2_f, mem2_ff, mem2_fff : STD_LOGIC_VECTOR(NBITS_DATA-1 downto 0) := (others => '0');
  
  type wg_state_type is (st_idle, st_gettingFirstLine, st_gettingSecondLine, st_gettingLines, st_finish);
  signal wg_state : wg_state_type := st_idle;

  signal window_data_reg : window_type := (others => (others => (others => '0')));

  --attribute ramstyle : string;
  --attribute ramstyle of img_mem : signal is "M9K";
  --attribute ramstyle of line_mem0 : signal is "M9K";
  --attribute ramstyle of line_mem1 : signal is "M9K";
  --attribute ramstyle of line_mem2 : signal is "M9K";

begin

  data_proc: process (clk, rst_n) is
  begin  -- process data_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      col_counter <= (others => '0');
      line_counter <= (others => '0');
      index_firstLine <= x"0";
      index_secondLine <= x"1";
      index_thirdLine <= x"2";
    
      
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
            line_mem0(to_integer(col_counter)) <= pxl_data;
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
            col_counter <= col_counter;
            line_counter <= line_counter;
          end if;


        when st_gettingSecondLine =>
          if (pxl_valid = '1') then
            line_mem1(to_integer(col_counter)) <= pxl_data;
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
            col_counter <= col_counter;
            line_counter <= line_counter;
          end if;

        when st_gettingLines =>
          if (pxl_valid = '1') then
            if (index_thirdLine = x"0") then
              line_mem0(to_integer(col_counter)) <= pxl_data;
            elsif (index_thirdLine = x"1") then
              line_mem1(to_integer(col_counter)) <= pxl_data;
            else
              line_mem2(to_integer(col_counter)) <= pxl_data;
            end if;
            
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
                              
            else
              wg_state <= st_gettingLines;
              col_counter <= col_counter + 1;
              line_counter <= line_counter;
            end if;
          else
            wg_state <= st_gettingLines;
            line_counter <= line_counter;
            col_counter <= col_counter;
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

      
      --flops com saidas das memorias
      if (pxl_valid = '1') then
        col_counter_f <= col_counter;
        line_counter_f <= line_counter;

        
        mem0_f <= line_mem0(to_integer(col_counter_f));
        mem0_ff <= mem0_f;
        mem0_fff <= mem0_ff;
      
        mem1_f <= line_mem1(to_integer(col_counter_f));
        mem1_ff <= mem1_f;
        mem1_fff <= mem1_ff;

        mem2_f <= line_mem2(to_integer(col_counter_f));
        mem2_ff <= mem2_f;
        mem2_fff <= mem2_ff;
      else
        col_counter_f <= col_counter_f;
        line_counter_f <= line_counter_f;
        
        mem0_f <= mem0_f;
        mem0_ff <= mem0_ff;
        mem0_fff <= mem0_fff;
      
        mem1_f <= mem1_f;
        mem1_ff <= mem1_ff;
        mem1_fff <= mem1_fff;

        mem2_f <= mem2_f;
        mem2_ff <= mem2_ff;
        mem2_fff <= mem2_fff;
      end if;      

      index_thirdLine_f <= index_thirdLine;
      index_thirdLine_ff <= index_thirdLine_f;
      
      if (pxl_valid = '1' and col_counter_f > KERNEL_W-2 and line_counter_f > KERNEL_H-2) then
        window_valid <= '1';
      else
        window_valid <= '0';
       
        
      end if;
      

      
    end if;
  end process win_proc;

  window_data(0)(0) <= mem0_fff when index_thirdLine_ff = x"2"
                           else mem1_fff when index_thirdline = x"0"
                           else mem2_fff;

  window_data(0)(1) <= mem0_ff when index_thirdLine_ff = x"2"
                           else mem1_ff when index_thirdline = x"0"
                           else mem2_ff;

  window_data(0)(2) <= mem0_f when index_thirdLine_ff = x"2"
                           else mem1_f when index_thirdline = x"0"
                           else mem2_f;

  window_data(1)(0) <= mem1_fff when index_thirdLine_ff = x"2"
                           else mem2_fff when index_thirdline = x"0"
                           else mem0_fff;

  window_data(1)(1) <= mem1_ff when index_thirdLine_ff = x"2"
                           else mem2_ff when index_thirdline = x"0"
                           else mem0_ff;

  window_data(1)(2) <= mem1_f when index_thirdLine_ff = x"2"
                           else mem2_f when index_thirdline = x"0"
                           else mem0_f;

  window_data(2)(0) <= mem2_fff when index_thirdLine_ff = x"2"
                           else mem0_fff when index_thirdline = x"0"
                           else mem1_fff;

  window_data(2)(1) <= mem2_ff when index_thirdLine_ff = x"2"
                           else mem0_ff when index_thirdline = x"0"
                           else mem1_ff;

  window_data(2)(2) <= mem2_f when index_thirdLine_ff = x"2"
                           else mem0_f when index_thirdline = x"0"
                           else mem1_f;
    
end architecture bhv;
