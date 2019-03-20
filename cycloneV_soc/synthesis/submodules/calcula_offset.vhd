-------------------------------------------------------------------------------
-- Title      : calcula_offset
-- Project    : 
-------------------------------------------------------------------------------
-- File       : calcula_offset.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-28
-- Last update: 2019-03-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o calculo do offset a partir do mutual information
-- e da entropia.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-28  1.0      mdrumond        Created
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Bibliotecas
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

LIBRARY altera_mf;
USE altera_mf.all;

library altera;
use altera.altera_primitives_components.all;

-------------------------------------------------------------------------------
-- Entidade
-------------------------------------------------------------------------------
entity calcula_offset is
  generic (
    LARGURA_BINS             : integer := 16;
    NUMERO_SHIFTS            : integer := 16;
    LARGURA_SHIFTS           : integer := 4;
    LARGURA_PASSO            : integer := 2;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    LARGURA_ENTRADAS         : integer := 27
    );
  port (
    clk, rst_n         : in  std_logic;
    entropia_in, mi_in : in  std_logic_vector(LARGURA_ENTRADAS-1 downto 0);
    comeca_calculo     : in  std_logic;
    fim_calculo        : out std_logic;
    limpa_estado       : in  std_logic;
    offset_out         : out std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);
    escolhe_metodo     : in  std_logic_vector(1 downto 0)
    );
end entity calcula_offset;

-------------------------------------------------------------------------------
-- Arquitetura 
-------------------------------------------------------------------------------
architecture fpga of calcula_offset is

  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------
  constant DEF_MENOR_VALOR : signed(LARGURA_ENTRADAS+2-1 downto 0) := (LARGURA_ENTRADAS+2-1 => '0', others => '1');

  constant BUFFER_SIZE   : integer := 8;
  constant W_BUFFER_SIZE : integer := 3;
  constant ACCUM_SIZE    : integer := LARGURA_CONTADOR_COLUNAS + W_BUFFER_SIZE;

  constant PXL_DISTANCE_FOR_GOOD_OFFSET : unsigned(3 downto 0) := x"5";
  constant BEST_VALUE_TABLE_SIZE : integer := 2;

  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------
  subtype offset_t is unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0);
  type offset_buffer_t is array(integer range <>) of offset_t;

  subtype offset_accum_t is unsigned(ACCUM_SIZE-1 downto 0);
  type offset_accum_array_t is array(integer range <>) of offset_accum_t;

  subtype raw_value_t is signed(LARGURA_ENTRADAS+2-1 downto 0);
  type table_raw_value_t is array(0 to BEST_VALUE_TABLE_SIZE-1) of raw_value_t;
  type table_shift_value_t is array(0 to BEST_VALUE_TABLE_SIZE-1) of unsigned(LARGURA_SHIFTS-1 downto 0);

  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------
  type flop_calc_valor_out_t is record
    valor  : signed(LARGURA_ENTRADAS+2-1 downto 0);
    valido : std_logic;
  end record flop_calc_valor_out_t;




  constant DEF_FLOP_CALC_VALOR_OUT : flop_calc_valor_out_t := (
    valor  => (others => '0'),
    valido => '0'
    );

-- Rodrigo
  type best_values_table_t is record
    best_values  : table_raw_value_t;
    tie_break_values : table_raw_value_t;
    shift_values : table_shift_value_t;
  end record best_values_table_t;
  
  constant DEF_BEST_VALUES_TABLE : best_values_table_t := (
    best_values  => (others => DEF_MENOR_VALOR),
    tie_break_values  => (others => DEF_MENOR_VALOR),
    shift_values  => (others => (others => '0'))
    );
--------
  
  
  -----------------------------------------------------------------------------
  -- Funcoes
  -----------------------------------------------------------------------------
  -- purpose: Sum an array of accums
  -- Esse codigo sintetiza uma arvore binaria de somadores para gerar o acumulador
  function sum_accum (accum_array : offset_accum_array_t) return offset_accum_t is
    variable accum_first_half, accum_second_half : offset_accum_array_t(0 to accum_array'length/2-1);
    variable accum_sum : offset_accum_t;
    variable middle_array : integer;
  begin  -- function sum_accum
    middle_array :=  accum_array'length/2;

    -- recursivelly build the sum tree
    if accum_array'length > 2 then
      accum_first_half :=  accum_array(0 to middle_array-1);
      accum_second_half := accum_array(middle_array to accum_array'length-1);
      accum_sum := sum_accum(accum_first_half) +
                   sum_accum(accum_second_half);
    -- end of recursion
    else
      accum_sum := accum_array(0) + accum_array(1);
    end if;

    return accum_sum;
  end function sum_accum;

  -----------------------------------------------------------------------------

    -- purpose: Calc Menor Valor
  function encontra_menor_valor (tie_breaker_values : table_raw_value_t) return integer is
    variable tmp : raw_value_t := DEF_MENOR_VALOR; 
    variable index : integer := 0;
  begin  -- 
    for i in 0 to BEST_VALUE_TABLE_SIZE-1 loop
      if tie_breaker_values(i) < tmp then
        tmp := tie_breaker_values(i);
        index := i;
      end if;
    end loop;

    return index;
    
  end function encontra_menor_valor;

  -- purpose: Soma o offset em um ciclo
  function sum_offset (offset_buffer : offset_buffer_t) return offset_t is
    variable accum : offset_accum_array_t(0 to BUFFER_SIZE-1);
    variable accum_end : offset_accum_t;
  begin  -- function sum_offset
    for i in 0 to BUFFER_SIZE-1 loop
      accum(i) := resize(offset_buffer(i),ACCUM_SIZE);
    end loop;  -- i

    accum_end := sum_accum(accum);
    
    return offset_t(accum_end(ACCUM_SIZE-1 downto W_BUFFER_SIZE));
    
  end function sum_offset;

  -----------------------------------------------------------------------------
  -- Sinais
  -----------------------------------------------------------------------------
  signal shift_counter : unsigned(LARGURA_SHIFTS-1 downto 0) := (others => '0');
  signal offset_out_i  : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0) := (others => '0');

  signal menor_valor : signed(LARGURA_ENTRADAS+2-1 downto 0) := DEF_MENOR_VALOR;
  
  signal flop_calc_valor_out : flop_calc_valor_out_t := DEF_FLOP_CALC_VALOR_OUT;

  signal offset_circ_buffer : offset_buffer_t(BUFFER_SIZE-1 downto 0);

  signal offset_circ_buffer_ptr : unsigned(W_BUFFER_SIZE-1 downto 0);

  signal updating_buffer : std_logic := '0';

  signal escolhe_metodo_i : std_logic_vector(1 downto 0);

  signal ent_value, mi_value, tie_break_value : signed(LARGURA_ENTRADAS+2-1 downto 0) := DEF_MENOR_VALOR;

  signal pxl_distance_for_new_good_offset : unsigned(3 downto 0) := (others => '0');
  signal shift_pxl : std_logic_vector(3 downto 0) := (others => '0');

  signal best_values_table : best_values_table_t := DEF_BEST_VALUES_TABLE;

  signal tb_select : std_logic_vector(0 downto 0) := (others => '0');
  

 
  
  -----------------------------------------------------------------------------

begin  -- architecture fpga

  dFfVectorSynchronizer_1 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => 2
      )
    port map (
      nReset => rst_n,
      clock  => clk,
      input  => escolhe_metodo,
      output => escolhe_metodo_i
      );
  
  -----------------------------------------------------------------------------
  -- purpose: Implementa o bloco de calculo de offset
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      shift_counter       <= (others => '0');
      flop_calc_valor_out <= DEF_FLOP_CALC_VALOR_OUT;
      menor_valor         <= DEF_MENOR_VALOR;
      offset_out_i        <= (others => '0');
      offset_out          <= (others => '0');
      best_values_table   <= DEF_BEST_VALUES_TABLE;
      updating_buffer <= '0';
      offset_circ_buffer_ptr <= (others => '0');
      
    elsif clk'event and clk = '1' then  -- rising clock edge

      if escolhe_metodo_i = "00" then -- : Manual
        --flop_calc_valor_out.valor <= (others => '0');
      elsif escolhe_metodo_i = "01" then -- : Mutual Information
        flop_calc_valor_out.valor <= -shift_left(resize(signed(mi_in), LARGURA_ENTRADAS+2), 1);
      elsif escolhe_metodo_i = "10" then -- : Entropia
        flop_calc_valor_out.valor <= resize(signed(entropia_in), LARGURA_ENTRADAS+2);
      else --    escolhe_metodo_i = "11" : Soma ponderada de Mutual Information e Entropia, alpha hardcoded
        flop_calc_valor_out.valor <= resize(signed(entropia_in), LARGURA_ENTRADAS+2) -
                                     shift_left(resize(signed(mi_in), LARGURA_ENTRADAS+2), 1);
      end if;

      flop_calc_valor_out.valido <= comeca_calculo;
      ent_value <= resize(signed(entropia_in), LARGURA_ENTRADAS+2);  -- Rodrigo
      mi_value <= -shift_left(resize(signed(mi_in), LARGURA_ENTRADAS+2), 1);


      

      fim_calculo <= '0';
      if '1' = flop_calc_valor_out.valido then
        fim_calculo   <= '1';
        shift_counter <= shift_counter + 1;

        -- Rodrigo
        if pxl_distance_for_new_good_offset > 0 then
          pxl_distance_for_new_good_offset <= pxl_distance_for_new_good_offset - 1;
        else
          pxl_distance_for_new_good_offset <= (others => '0');
        end if;

        if pxl_distance_for_new_good_offset = 0 then
          for i in 0 to BEST_VALUE_TABLE_SIZE-1 loop
            if flop_calc_valor_out.valor + shift_right(flop_calc_valor_out.valor,4) < best_values_table.best_values(i) then
--            if flop_calc_valor_out.valor < best_values_table.best_values(i) then
              best_values_table.best_values(i) <= flop_calc_valor_out.valor;
              best_values_table.tie_break_values(i) <= tie_break_value;
              best_values_table.shift_values(i) <= shift_counter;
              pxl_distance_for_new_good_offset <= unsigned(shift_pxl); --PXL_DISTANCE_FOR_GOOD_OFFSET;
              for j in i+1 to BEST_VALUE_TABLE_SIZE-1 loop
                best_values_table.best_values(j) <=  best_values_table.best_values(j-1);
                best_values_table.tie_break_values(j) <= best_values_table.tie_break_values(j-1);
                best_values_table.shift_values(j) <= best_values_table.shift_values(j-1);
              end loop;
            end if;            
          end loop;
        else
          best_values_table <= best_values_table;
        end if;      

        if flop_calc_valor_out.valor < menor_valor then
          menor_valor  <= flop_calc_valor_out.valor;
          offset_out_i <= (NUMERO_SHIFTS-1)*(2**LARGURA_PASSO) -
                          shift_left(resize(shift_counter, LARGURA_CONTADOR_COLUNAS), LARGURA_PASSO);
        end if;
      end if;

      if '1' = limpa_estado then
        shift_counter <= (others => '0');
        --offset_out    <= std_logic_vector(offset_out_i);
        menor_valor   <= DEF_MENOR_VALOR;
        best_values_table <= DEF_BEST_VALUES_TABLE;
        offset_circ_buffer_ptr <= offset_circ_buffer_ptr + 1;

        offset_circ_buffer(to_integer(offset_circ_buffer_ptr)) <= (NUMERO_SHIFTS-1)*(2**LARGURA_PASSO) -
                                                                  shift_left(resize(best_values_table.shift_values(encontra_menor_valor(best_values_table.tie_break_values)),
                                                                                                                   LARGURA_CONTADOR_COLUNAS), LARGURA_PASSO);
        
      end if;

      -- atrasa o limpa estado em 1 ciclo para dar tempo de atualizar o buffer
      -- antes de fazer a soma
      updating_buffer <= limpa_estado;
      if '1' = updating_buffer then         
        -- Media dos ultimos 4 menores valores de offset
        offset_out <= std_logic_vector(sum_offset(offset_circ_buffer));
      end if;
      
    end if;
  end process clk_proc;

  tie_break_value <= mi_value when tb_select(0) = '1' else ent_value;
  altsource_probe_tb :  altera_mf.altera_mf_components.altsource_probe
     GENERIC MAP (
       enable_metastability => "YES",
       instance_id => "tbfu",
       probe_width => 1,
       sld_auto_instance_index => "YES",
       sld_instance_index => 0,
       source_initial_value => "0",
       source_width => 1,
       lpm_type => "altsource_probe"
       )
     PORT MAP (
       probe => tb_select,
       source_clk => clk,
       source_ena => '1',
       source => tb_select
		 
       );

    altsource_probe_pxld :  altera_mf.altera_mf_components.altsource_probe
     GENERIC MAP (
       enable_metastability => "YES",
       instance_id => "pxld",
       probe_width => 1,
       sld_auto_instance_index => "YES",
       sld_instance_index => 0,
       source_initial_value => x"0",
       source_width => 4,
       lpm_type => "altsource_probe"
       )
     PORT MAP (
       probe => tb_select,
       source_clk => clk,
       source_ena => '1',
       source => shift_pxl
		 
       );
  -- usar gravar offset out em um buffer circular
  -- dar como saida a media de todos os valores do buffer

end architecture fpga;
