-- Title      : swir_emulator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : swir_emulator.vhd
-- Author     :   <rodrigo.oliveira@TESLA>
-- Company    : 
-- Created    : 2014-12-01
-- Last update: 2016-10-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: emulador do sensor swir
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-12-01  1.0      rodrigo.oliveira	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity swir_emulator is
  generic (
    NUMERO_COLUNAS : integer := 320;
    NUMERO_LINHAS  : integer := 256;
    SIMULATOR_PATTERN : boolean := true);
  port (
    pxl_clock : in std_logic;
    s_clock  : in  std_logic;
    rst_n    : in  std_logic;
    lsync    : in  std_logic;
    fsync    : in  std_logic;
    data_out : out std_logic_vector(7 downto 0));

end entity swir_emulator;

architecture bhv of swir_emulator is

  
signal data : unsigned (9 downto 0) := (others => '0');
signal linha_counter : unsigned(9 downto 0) := (others => '0');
signal clk_counter : unsigned(10 downto 0) := (others => '0');
signal line_counter : unsigned(9 downto 0) := (others => '0');
signal col_counter : unsigned(9 downto 0) := (others => '0');
signal col_counter_f : unsigned(9 downto 0);
signal col_counter_f2 : unsigned(9 downto 0);
signal col_counter_f3 : unsigned(9 downto 0);
signal start_cont : std_logic := '0';

constant LINHAS_TESTE : integer := 2;
constant CINZA : unsigned(9 downto 0) := "0010000000";
constant PRETO : unsigned(9 downto 0):= "0000000011";
constant BRANCO : unsigned(9 downto 0) := "0011110000";

  
begin  -- architecture bhv



-- purpose: 
 controle_proc: process (s_clock, rst_n, fsync, lsync) is
  begin  -- process controle_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      linha_counter <= (others => '0');
      clk_counter <= (others => '0');
    elsif s_clock'event and s_clock = '1' then  -- rising clock edge
      if fsync = '1' then
        clk_counter <= clk_counter + 1;
        if lsync = '1' then
          linha_counter <= linha_counter + 1;
          clk_counter <= (others => '0');
        end if;
      else
        linha_counter <= (others => '0');
        clk_counter <= (others => '0');
      end if;
     end if;
    --end if;
  end process controle_proc;

-- purpose:
col_process: process (pxl_clock, rst_n) is
begin  -- process data_process
  if rst_n = '0' then                   -- asynchronous reset (active low)
    col_counter <= (others => '0');
    col_counter_f <= (others => '0');
    col_counter_f2 <= (others => '0');
    col_counter_f3 <= (others => '0');
  elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
    col_counter <= col_counter_f;
    --col_counter_f3 <= col_counter_f2;
    --col_counter <= col_counter_f3;
    if clk_counter = 2 then
      start_cont <= '1';
    end if;
    if linha_counter > LINHAS_TESTE and clk_counter > 1  and start_cont = '1' then
      if col_counter_f < NUMERO_COLUNAS - 1  then
        col_counter_f <= col_counter_f + 1;
      else
        col_counter_f <= (others => '0');
        start_cont <= '0';
      end if;
    end if;
  end if;
end process col_process;


gera_padrao_projetor : if not SIMULATOR_PATTERN generate  
   pattern_process: process (pxl_clock, rst_n) is
   begin  -- process pattern_process
     if rst_n = '0' then                   -- asynchronous reset (active low)
       data <= (others => '0');
     elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
       if col_counter < NUMERO_COLUNAS/2-1 and linha_counter < NUMERO_LINHAS/2-1 then
         data <= CINZA;
       elsif col_counter < NUMERO_COLUNAS/2-1 and linha_counter > NUMERO_LINHAS/2-1 then
         data <= BRANCO;
       elsif col_counter > NUMERO_COLUNAS/2-1 and linha_counter < NUMERO_LINHAS/2-1 then
         data <= PRETO;
       else
         data <= CINZA;
       end if;    
     end if;
   end process pattern_process;
end generate gera_padrao_projetor;

gera_padrao_simulacao : if SIMULATOR_PATTERN generate
   pattern_process2: process (pxl_clock, rst_n) is
   begin  -- process pattern_process
     if rst_n = '0' then                   -- asynchronous reset (active low)
       data <= (others => '0');
     elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
       if col_counter = NUMERO_COLUNAS/2-1 or col_counter = NUMERO_COLUNAS-1 then
         data <= (others => '0');
       else
         data <= data + 1;
       end if;
     end if;
   end process pattern_process2;
end generate gera_padrao_simulacao;
    
data_out <= std_logic_vector(data(7 downto 0));
  
end architecture bhv;


-------------------------------------------------------------------------------
-- Title      : swir_emulator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : swir_emulator.vhd
-- Author     :   <rodrigo.oliveira@TESLA>
-- Company    : 
-- Created    : 2014-12-01
-- Last update: 2015-01-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: emulador do sensor swir
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-12-01  1.0      rodrigo.oliveira	Created
-------------------------------------------------------------------------------

--library IEEE;
--use IEEE.std_logic_1164.all;
--use ieee.numeric_std.all;

--entity swir_emulator is
--  generic (
--    NUMERO_COLUNAS : integer := 320;
--    NUMERO_LINHAS  : integer := 256;
--    SIMULATOR_PATTERN : boolean := true);
--  port (
--    pxl_clock : in std_logic;
--    s_clock  : in  std_logic;
--    rst_n    : in  std_logic;
--    lsync    : in  std_logic;
--    fsync    : in  std_logic;
--    data_out : out std_logic_vector(9 downto 0));

--end entity swir_emulator;

--architecture bhv of swir_emulator is

  
--signal data : unsigned (9 downto 0) := (others => '0');
--signal linha_counter : unsigned(9 downto 0) := (others => '0');
--signal clk_counter : unsigned(10 downto 0) := (others => '0');
--signal line_counter : unsigned(9 downto 0) := (others => '0');
--signal col_counter : unsigned(9 downto 0) := (others => '0');
--signal col_counter_f : unsigned(9 downto 0);
--signal col_counter_f2 : unsigned(9 downto 0);
--signal col_counter_f3 : unsigned(9 downto 0);
--signal start_cont : std_logic := '0';

--constant LINHAS_TESTE : integer := 2;
--constant CINZA : unsigned(9 downto 0) := "1000000000";
--constant PRETO : unsigned(9 downto 0):= "0000001100";
--constant BRANCO : unsigned(9 downto 0) := "1111000000";

  
--begin  -- architecture bhv



---- purpose: 
-- controle_proc: process (s_clock, rst_n, fsync, lsync) is
--  begin  -- process controle_proc
--    if rst_n = '0' then                 -- asynchronous reset (active low)
--      linha_counter <= (others => '0');
--      clk_counter <= (others => '0');
--    elsif s_clock'event and s_clock = '1' then  -- rising clock edge
--      if fsync = '1' then
--        clk_counter <= clk_counter + 1;
--        if lsync = '1' then
--          linha_counter <= linha_counter + 1;
--          clk_counter <= (others => '0');
--        end if;
--      else
--        linha_counter <= (others => '0');
--        clk_counter <= (others => '0');
--      end if;
--     end if;
--    --end if;
--  end process controle_proc;

---- purpose:
--col_process: process (pxl_clock, rst_n) is
--begin  -- process data_process
--  if rst_n = '0' then                   -- asynchronous reset (active low)
--    col_counter <= (others => '0');
--    col_counter_f <= (others => '0');
--    col_counter_f2 <= (others => '0');
--    col_counter_f3 <= (others => '0');
--  elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
--    col_counter <= col_counter_f;
--    --col_counter_f3 <= col_counter_f2;
--    --col_counter <= col_counter_f3;
--    if clk_counter = 2 then
--      start_cont <= '1';
--    end if;
--    if linha_counter > LINHAS_TESTE and clk_counter > 1  and start_cont = '1' then
--      if col_counter_f < NUMERO_COLUNAS - 1  then
--        col_counter_f <= col_counter_f + 1;
--      else
--        col_counter_f <= (others => '0');
--        start_cont <= '0';
--      end if;
--    end if;
--  end if;
--end process col_process;


--gera_padrao_projetor : if not SIMULATOR_PATTERN generate  
--   pattern_process: process (pxl_clock, rst_n) is
--   begin  -- process pattern_process
--     if rst_n = '0' then                   -- asynchronous reset (active low)
--       data <= (others => '0');
--     elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
--       if col_counter < NUMERO_COLUNAS/2-1 and linha_counter < NUMERO_LINHAS/2-1 then
--         data <= CINZA;
--       elsif col_counter < NUMERO_COLUNAS/2-1 and linha_counter > NUMERO_LINHAS/2-1 then
--         data <= BRANCO;
--       elsif col_counter > NUMERO_COLUNAS/2-1 and linha_counter < NUMERO_LINHAS/2-1 then
--         data <= PRETO;
--       else
--         data <= CINZA;
--       end if;    
--     end if;
--   end process pattern_process;
--end generate gera_padrao_projetor;

--gera_padrao_simulacao : if SIMULATOR_PATTERN generate
--   pattern_process2: process (pxl_clock, rst_n) is
--   begin  -- process pattern_process
--     if rst_n = '0' then                   -- asynchronous reset (active low)
--       data <= (others => '0');
--     elsif pxl_clock'event and pxl_clock = '1' then  -- rising clock edge
--       data <= data + 1;   
--     end if;
--   end process pattern_process2;
--end generate gera_padrao_simulacao;
    
--data_out <= std_logic_vector(data);
  
--end architecture bhv;
