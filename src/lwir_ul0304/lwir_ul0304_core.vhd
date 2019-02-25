-------------------------------------------------------------------------------
-- Title      : lwir_UL_03_04_controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : lwir_UL_03_04_controller.vhd
-- Author     :   <rodrigo@thomson>
-- Company    : 
-- Created    : 2015-08-07
-- Last update: 2019-02-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controlador Sensor Termal LWIR UL 03 04 1
--              CLOCK DE 7,5 MHz!!!!!!
-------------------------------------------------------------------------------
-- Copyright (c) 2015 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-08-07  1.0      rodrigo	Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--use work.megafunc_pkg.all;


entity lwir_UL_03_04_controller is
  generic (
    NUM_COLS       : integer          := 384;
    NUM_LINES      : integer          := 288;
    N_BITS_PXL     : integer          := 8;
    ROI_EN         : boolean          := true;
    ROI_COL        : integer          := 320;
    ROI_LINE       : integer          := 256;
    CLOCK_FREQ     : integer          := 7500000; --7500000;
    FRAME_RATE     : integer          := 20 --valor maximo : ~50 FPS a 7,5Mhz
    );

  port (
    clk, rst_n        : in   std_logic;
    en                : in   std_logic;
    invert_data       : in   std_logic;
    pxl_in            : in   std_logic_vector(N_BITS_PXL-1 downto 0);
    pxl_out           : out  std_logic_vector(N_BITS_PXL-1 downto 0);
    sens_syt          : out  std_logic; --frame sync
    sens_syl          : out  std_logic; --line sync
    sens_syp          : out  std_logic; --pxl sync
    pxl_valid         : out  std_logic --pxl_valido --- escrever na memoria
    );

end entity lwir_UL_03_04_controller;

architecture bhv of lwir_UL_03_04_controller is

  --CONSTANTES QUE VARIAM COM O CLOCK!!
  
  constant integration_time_inv : integer := 15625; -- = 64us^-1
  --constant integration_time_inv : integer := 11428; -- = 87,5us^-1
  --constant integration_time_inv : integer := 10000; -- = 100us^-1
  --constant integration_time_inv : integer := 2500; -- = 400us^-1

  -- FOLGA PARA AUMENTAR O TEMPO DE INTEGRAÇAO (TESTE SENSOR)
  constant integration_cycles_folga : integer := 0;
  
  constant integration_cycles : integer := CLOCK_FREQ/integration_time_inv + --calc: 64us * clk_freq (Freq do Clock);
                                           integration_cycles_folga;
  
  constant syl_time_inv : integer := 212766; -- 4,7us^-1                                                   
  constant syl_cycles : integer := CLOCK_FREQ/syl_time_inv; --PROXIMO DE 4.7us +/ 30%; --calc: int (4.7us*f)

  -- DEFINICAO DA DURACAO DOS CICLOS
  constant syp_clock_cyles : integer := 1;
  constant syp_cycles : integer := syp_clock_cyles*NUM_COLS;
  
  constant between_lines_cycles : integer := integration_cycles - syl_cycles;
  constant fp_pxl_cycles : integer := (between_lines_cycles - syp_cycles)/2;
  constant bp_pxl_cycles : integer := between_lines_cycles - syp_cycles - fp_pxl_cycles;
  
  constant syt_cycles_folga : integer := integration_cycles;
  constant syt_cycles : integer := integration_cycles + syt_cycles_folga;
  

  constant fp_line_cycles : integer := fp_pxl_cycles; --Valor arbitrario, mas
                                                      --esse ta bom
  constant fps_cycles : integer := CLOCK_FREQ/FRAME_RATE;
  constant total_cycles : integer := syt_cycles + fp_line_cycles + (integration_cycles*NUM_LINES);
  constant first_line_wait : integer := fps_cycles - total_cycles; --controle frame_rate!
  --constant first_line_wait : integer := syt_cycles; --controle frame_rate!
  

  constant NUM_LINES_PLUS : integer := NUM_LINES+1;

  --RANGE PARA REFERENCIA DE GERACAO DOS SINAIS DO SENSOR
  constant init_syt : integer := 0;
  constant end_syt : integer := syt_cycles;

  constant init_syl : integer := end_syt + fp_line_cycles + first_line_wait;
  constant end_syl : integer := init_syl + syl_cycles;

  constant init_syp : integer := end_syl + fp_pxl_cycles;
  constant end_syp : integer := init_syp + syp_cycles;

  constant wait_pxl_bp : integer := end_syp + bp_pxl_cycles;

  signal counter : integer := 0;
  signal line_counter : integer := 0;
 
  signal pxl_aux : std_logic_vector(N_BITS_PXL-1 downto 0);
  signal pxl_valid_aux : std_logic := '0';

  signal pixel_in_f1, pixel_in_f2 : std_logic_vector(N_BITS_PXL-1 downto 0);

  --CALCULO DO OFFSET PARA O ROI
  constant roi_col_init  : integer := (NUM_COLS - ROI_COL)/2 + init_syp;
  constant roi_col_end  : integer := roi_col_init + ROI_COL;
  constant roi_line_init : integer := (NUM_LINES - ROI_LINE)/2;
  constant roi_line_end : integer := roi_line_init + ROI_LINE;
  
begin  -- architecture bhv

  dff_proc: process (clk, rst_n) is
  begin  -- process dff_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      pixel_in_f1 <= (others => '0');
      pixel_in_f2 <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      pixel_in_f1 <= pxl_in;
      pixel_in_f2 <= pixel_in_f1;
    end if;
  end process dff_proc;
  
proc_counter: process (clk, rst_n) is
begin  -- process proc_counter
  if rst_n = '0' then                   -- asynchronous reset (active low)
    counter <= 0;
    line_counter <= 0;
  elsif clk'event and clk = '1' then    -- rising clock edge
    if en = '1' then
      if counter = init_syl+1 then
        line_counter <= line_counter + 1;
      else
        line_counter <= line_counter;
      end if;
--line_counter incrementa antes, logo comeca da linha 1. 0 +1 eh pq a primeira
--linha eh soh integration time
      if line_counter = NUM_LINES+1 and counter = wait_pxl_bp then
        counter <= 0;
        line_counter <= 0;
      elsif counter = wait_pxl_bp then
        counter <= init_syl;
      else
        counter <= counter + 1;
      end if;
    else
      counter <= counter;
      line_counter <= line_counter;
    end if;
    
  end if;
end process proc_counter;

sens_syp <= clk when (counter >= init_syp) and (counter < end_syp) and en = '1' else '0';
sens_syl <= '1' when (counter >= init_syl) and (counter < end_syl) and en = '1' else '0';
sens_syt <= '1' when (counter >= init_syt) and (counter < end_syt) and en = '1' else '0';


INVERTER_BIT : for i in 0 to N_BITS_PXL-1 generate
  pxl_aux(i) <= not pixel_in_f2(i);
end generate INVERTER_BIT;
               
--PXL VALIDO (SEM ROI)
pxl_valid_aux <= '1' when (counter >= init_syp) and (line_counter > 1) and (counter < end_syp) else '0';             

-- DETERMINA QDO PODE ESCREVER NA MEMORIA (COM OU SEM ROI)               
pxl_valid_roi : if ROI_EN generate
  pxl_valid <= '1' when (pxl_valid_aux = '1') and (counter >= roi_col_init) and (counter < roi_col_end)
                and (line_counter >= roi_line_init) and (line_counter < roi_line_end) else '0';
end generate pxl_valid_roi;
                
pxl_valid_non_roi : if not ROI_EN generate
  pxl_valid <= '1' when pxl_valid_aux = '1';
end generate pxl_valid_non_roi;                           

-- pixel_out => inverso ou não (depende do condicionamento da placa)
                    -- pode ser alterado on-the-fly
pxl_out <= pxl_aux when invert_data = '1' else pixel_in_f2;
                    
end architecture bhv;
