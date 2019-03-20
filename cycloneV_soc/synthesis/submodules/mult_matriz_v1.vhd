-------------------------------------------------------------------------------
-- Title      : mult_matriz_v1
-- Project    : 
-------------------------------------------------------------------------------
-- File       : mult_matriz_v1.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-08-21
-- Last update: 2015-03-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa a multiplicacao sequencial da matriz de homografia
--              pela matriz das coordenadas
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-08-21  1.0      mdrumond        Created
-- 2014-08-14  1.1    rodrigo.oliveira    Updated   Acrescimo dos divisores
-- 2014-09-04  1.2    rodrigo.oliveira     Updated   Parametrizacao dos bits
--                                                  de inteiro e fracao
--             1.3    rodrigo.oliveira   Updated    Generizacao do uso ou nao
--                                                  de divisores
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.megafunc_pkg.all;
use work.uteis.all;
library lpm;
use lpm.all;

entity mult_matriz_v1 is
  generic (
    DEF_MATRIZ_HOMOG_IN     : matriz_homog_t     := DEF_MATRIZ_HOMOG;
    TAMANHO_BURST           : integer            := 16;
    BUFFER_MEM              : buffer_ping_pong_t := MEM_MAP_BUFFER_DEFAULT;
    NUMERO_COLUNAS_IN       : integer            := 320;
    NUMERO_COLUNAS_OUT      : integer            := 320+64;
    LARGURA_CONTADOR_COLUNA : integer            := 10;
    NUMERO_LINHAS_IN        : integer            := 256;
    NUMERO_LINHAS_OUT       : integer            := 256;
    LARGURA_CONTADOR_LINHA  : integer            := 9;
    CICLOS_LATENCIA         : integer            := 32;
    NUMERO_BITS_INTEIRO     : integer            := 10;
    NUMERO_BITS_FRACAO      : integer            := 10;
    USA_DIVISOR             : integer            := 1;
    ADDR_WORD_ZERO          : endr_mem_t         := (others => '1'));

  port (
    mem_clk, clk, rst_n : in  std_logic;
    mm_comeca_quadro    : in  std_logic;
    matriz_homo         : in  matriz_homog_t;
    mm_curr_buffer_in   : in  buffer_id_t;
    mm_get_prox_endr    : in  std_logic;
    mm_fim_quadro       : out std_logic;
    mm_endr_out         : out endr_mem_t;
    mm_endr_disponivel  : out std_logic
    );

  
end entity mult_matriz_v1;

architecture fpga_arch of mult_matriz_v1 is
  attribute multstyle              : string;
  attribute multstyle of fpga_arch : architecture is "dsp";

  constant LARGURA_MULTIPLICACAO_IN  : integer := 18;
  constant LARGURA_MULTIPLICACAO_OUT : integer := 36;

  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG : integer := NUMERO_BITS_FRACAO;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG : integer := NUMERO_BITS_INTEIRO;
  constant LARGURA_PONTO_MATRIZ_HOMOG : integer := NUMERO_BITS_INTEIRO + NUMERO_BITS_FRACAO + 1;

  
  constant DEF_LINHA_MATRIZ_HOMOG : linha_matriz_homog_t :=
    ((others => '0'), (others => '0'), (others => '0'));
  constant DEF_MATRIZ_HOMOG : matriz_homog_t :=
    (others => DEF_LINHA_MATRIZ_HOMOG);

  constant NUMERO_COLUNAS_IN_COORD : integer
    := NUMERO_COLUNAS_IN*(2**LARGURA_FRAC_PONTO_MATRIZ_HOMOG);
  constant NUMERO_LINHAS_IN_COORD : integer
    := NUMERO_LINHAS_IN*(2**LARGURA_FRAC_PONTO_MATRIZ_HOMOG);
  
  subtype ponto_coord_t is signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
  type coord_t is array (0 to 2) of ponto_coord_t;
  constant DEF_COORD : coord_t := (others => (others => '0'));

  --type estado_t is (ST_IDLE, ST_FRAME, ST_ESPERA_FIM_QUADRO);
  type estado_t is (ST_IDLE, ST_FRAME);
  type flop_controle_t is record
    estado       : estado_t;
    init_frame   : std_logic;
    init_lin     : std_logic;
    incr_lin     : std_logic;
    incr_col     : std_logic;
    coord_valida : std_logic;
    fim_quadro   : std_logic;
    col_ctr      : unsigned(LARGURA_CONTADOR_COLUNA downto 0);
    lin_ctr      : unsigned(LARGURA_CONTADOR_LINHA downto 0);
  end record flop_controle_t;
  constant DEF_FLOP_CONTROLE : flop_controle_t := (
    estado       => ST_IDLE,
    init_frame   => '0',
    init_lin     => '0',
    incr_lin     => '0',
    incr_col     => '0',
    coord_valida => '0',
    fim_quadro   => '0',
    col_ctr      => (others => '0'),
    lin_ctr      => (others => '0'));
  signal flop_controle : flop_controle_t := DEF_FLOP_CONTROLE;

  type flop_init_t is record
    comeca_quadro : std_logic;
  end record flop_init_t;
  constant DEF_FLOP_INIT : flop_init_t := (
    comeca_quadro => '0');
  signal flop_init : flop_init_t := DEF_FLOP_INIT;

  type flop_incr_accum_t is record      -- Flop do 1 estagio do pipeline
    coord_accum_col : coord_t;
    coord_accum_lin : coord_t;
    fim_quadro      : std_logic;
    coord_valida    : std_logic;
  end record flop_incr_accum_t;
  constant DEF_FLOP_INCR_ACCUM : flop_incr_accum_t := (
    coord_accum_lin => DEF_COORD,
    coord_accum_col => DEF_COORD,
    fim_quadro      => '0',
    coord_valida    => '0');
  signal flop_incr_accum : flop_incr_accum_t := DEF_FLOP_INCR_ACCUM;

  type flop_res_accum_t is record       -- Flop do 2 estagio do pipeline
    coord_accum_res : coord_t;
    coord_valida    : std_logic;
    fim_quadro      : std_logic;
  end record flop_res_accum_t;
  constant DEF_FLOP_RES_ACCUM : flop_res_accum_t := (
    coord_accum_res => DEF_COORD,
    coord_valida    => '0',
    fim_quadro      => '0');
  signal flop_res_accum : flop_res_accum_t := DEF_FLOP_RES_ACCUM;

  type flop_endr_calc_t is record  -- flop de entrada do calculo do endereco
    lin_offset     : endr_mem_t;
    col_offset     : endr_mem_t;
    fim_quadro     : std_logic;
    valido         : std_logic;
    dentro_limites : std_logic;
  end record flop_endr_calc_t;
  constant DEF_FLOP_ENDR_CALC : flop_endr_calc_t := (
    lin_offset     => (others => '0'),
    col_offset     => (others => '0'),
    fim_quadro     => '0',
    valido         => '0',
    dentro_limites => '0');
  signal flop_endr_calc : flop_endr_calc_t := DEF_FLOP_ENDR_CALC;

  type flop_coord_t is record
    coord_x : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
    coord_y : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
  end record flop_coord_t;
  constant DEF_flop_coord : flop_coord_t := (
    coord_x => (others => '0'),
    coord_y => (others => '0'));
  signal flop_coord : flop_coord_t := DEF_flop_coord;

  type flop_result_div_t is record
    div_coord_x : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
    div_coord_y : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
  end record flop_result_div_t;
  constant DEF_flop_result_div : flop_result_div_t := (
    div_coord_x => (others => '0'),
    div_coord_y => (others => '0'));
  signal flop_result_div : flop_result_div_t := DEF_flop_result_div;

  signal delayed_x : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0) := (others => '0');
  signal delayed_y : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0) := (others => '0');

  type flop_check_outofBounds_t is record
    outBounds   : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
    correctAddr : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
  end record flop_check_outofBounds_t;
  constant DEF_FLOP_CHECK_OUTOFBOUNDS : flop_check_outofBounds_t := (
    outBounds   => (others => '0'),
    correctAddr => (others => '0'));
  signal flop_check_outofBounds : flop_check_outofBounds_t := DEF_FLOP_CHECK_OUTOFBOUNDS;





  signal endr_calc_final : endr_mem_t;

  constant zero : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0) := (others => '0');

  signal fifo_endr_wr_burst_en : std_logic   := '0';
  signal curr_buffer           : buffer_id_t := (others => '0');
  signal fim_quadro            : std_logic;

  signal delayed_denominador : std_logic_vector(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);

  signal calc_offset      : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0);
  signal delayed_bits_in  : std_logic_vector(2 downto 0) := (others => '0');
  signal delayed_bits_out : std_logic_vector(2 downto 0) := (others => '0');

  signal outBounds   : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0) := (others => '0');
  signal correctAddr : signed(LARGURA_PONTO_MATRIZ_HOMOG-1 downto 0) := (others => '0');

  signal test_end_dispo : std_logic := '0';


  -- purpose: Calcula o offset da linha, multiplicando o numero de colunas da imagem de
  -- entrada pela coordenada da linha
  function calcula_offset_linha (
    signal accum_coord_linha : ponto_coord_t)
    return endr_mem_t is
    variable mul_result             : signed(LARGURA_MULTIPLICACAO_OUT-1 downto 0);
    -- Shift apenas para truncar o acumulador na hora de calcuar  a multiplicacao
    constant NUMERO_SHIFTS_ACCUM_IN : integer := LARGURA_FRAC_PONTO_MATRIZ_HOMOG;
    -- Shift pra remover o resto da parte fracional do resultado da multiplicacao
    constant NUMERO_SHIFTS_MUL_OUT  : integer := 0;
  begin  -- function calcula_offset_linha

    -- Corrige o numero de bits fracionais do resultado da multiplicaca automaticamente
    -- Resize+shift trunca para termos apenas 18 bits antes de multiplicar
    mul_result
      := resize(accum_coord_linha, LARGURA_MULTIPLICACAO_IN)*NUMERO_COLUNAS_IN;


    return std_logic_vector(
      resize(shift_right(mul_result,
                         NUMERO_SHIFTS_MUL_OUT),
             C_LARGURA_ENDR_MEM));    

  end function calcula_offset_linha;
begin  -- architecture fpga_arch

  -----------------------------------------------------------------------------
  -- Controle
  -----------------------------------------------------------------------------
-- purpose: Implementa o flop de estado da maquina
-- type   : sequential
-- inputs : clk, rst_n, prox_st
-- outputs: atual_st
  clk_proc : process (clk, rst_n) is
    variable col_mem_addr : unsigned(C_LARGURA_ENDR_MEM-1 downto 0);
  begin  -- process estado_atual_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_controle   <= DEF_FLOP_CONTROLE;
      flop_init       <= DEF_FLOP_INIT;
      flop_incr_accum <= DEF_FLOP_INCR_ACCUM;
      --flop_res_accum  <= DEF_FLOP_RES_ACCUM;
      flop_endr_calc  <= DEF_FLOP_ENDR_CALC;
      curr_buffer     <= (others => '0');
      fim_quadro      <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if '1' = fim_quadro then
        curr_buffer <= mm_curr_buffer_in;
      end if;


      flop_init.comeca_quadro    <= mm_comeca_quadro;
      flop_controle.init_frame   <= '0';
      flop_controle.init_lin     <= '0';
      flop_controle.incr_col     <= '0';
      flop_controle.incr_lin     <= '0';
      flop_controle.fim_quadro   <= '0';
      flop_controle.coord_valida <= '0';
      case flop_controle.estado is
        when ST_IDLE =>
          -- inicializa a geracao de enderecos
          if ('1' = flop_init.comeca_quadro) and ('1' = fifo_endr_wr_burst_en) then
            --if '1' = flop_init.comeca_quadro  then
            flop_controle.col_ctr    <= (others => '0');
            flop_controle.lin_ctr    <= (others => '0');
            flop_controle.init_frame <= '1';
            flop_controle.estado     <= ST_FRAME;
          end if;
          
        when ST_FRAME =>
          -- nao faz nada se a saida estiver ocupada
          if '1' = fifo_endr_wr_burst_en then
            flop_controle.col_ctr <= flop_controle.col_ctr + 1;
            if NUMERO_COLUNAS_OUT-1 = flop_controle.col_ctr then
              flop_controle.col_ctr  <= (others => '0');
              flop_controle.incr_lin <= '1';
              flop_controle.lin_ctr  <= flop_controle.lin_ctr + 1;
            end if;

            flop_controle.coord_valida <= '1';
            if 0 = flop_controle.col_ctr then
              flop_controle.init_lin <= '1';
            else
              flop_controle.incr_col <= '1';
            end if;


            if (NUMERO_COLUNAS_OUT-1 = flop_controle.col_ctr) and
              (NUMERO_LINHAS_OUT-1 = flop_controle.lin_ctr) then
              --flop_controle.estado     <= ST_ESPERA_FIM_QUADRO;
              flop_controle.estado     <= ST_IDLE;
              flop_controle.fim_quadro <= '1';
            end if;
          end if;

          --when ST_ESPERA_FIM_QUADRO =>
          --  if '1' = fifo_dlimite_data_q(1) then
          --    fim_quadro           <= '1';
          --    flop_controle.estado <= ST_IDLE;
          --  end if;

        when others =>
          flop_controle.estado <= ST_IDLE;
          
      end case;

      flop_incr_accum.coord_valida <= flop_controle.coord_valida;
      flop_incr_accum.fim_quadro   <= flop_controle.fim_quadro;

      if '1' = flop_controle.init_frame then
        flop_incr_accum.coord_accum_lin(0) <= resize(signed(matriz_homo(0)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_lin(1) <= resize(signed(matriz_homo(1)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_lin(2) <= resize(signed(matriz_homo(2)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
      elsif '1' = flop_controle.incr_lin then
        flop_incr_accum.coord_accum_lin(0)
          <= flop_incr_accum.coord_accum_lin(0) + resize(signed(matriz_homo(0)(1)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_lin(1)
          <= flop_incr_accum.coord_accum_lin(1) + resize(signed(matriz_homo(1)(1)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_lin(2)
          <= flop_incr_accum.coord_accum_lin(2) + resize(signed(matriz_homo(2)(1)), LARGURA_PONTO_MATRIZ_HOMOG);
      end if;

      if '1' = flop_controle.init_lin then
        if '1' = flop_controle.init_frame then
          flop_incr_accum.coord_accum_col(0) <= resize(signed(matriz_homo(0)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
          flop_incr_accum.coord_accum_col(1) <= resize(signed(matriz_homo(1)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
          flop_incr_accum.coord_accum_col(2) <= resize(signed(matriz_homo(2)(2)), LARGURA_PONTO_MATRIZ_HOMOG);
        else
          flop_incr_accum.coord_accum_col <= flop_incr_accum.coord_accum_lin;
        end if;
      elsif '1' = flop_controle.incr_col then
        flop_incr_accum.coord_accum_col(0)
          <= flop_incr_accum.coord_accum_col(0) +resize(signed(matriz_homo(0)(0)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_col(1)
          <= flop_incr_accum.coord_accum_col(1) +resize(signed(matriz_homo(1)(0)), LARGURA_PONTO_MATRIZ_HOMOG);
        flop_incr_accum.coord_accum_col(2)
          <= flop_incr_accum.coord_accum_col(2) +resize(signed(matriz_homo(2)(0)), LARGURA_PONTO_MATRIZ_HOMOG);
      end if;




      -------------------------------------------------------------------------
      -- Estagio do calculo do endereco
      flop_endr_calc.valido     <= flop_res_accum.coord_valida;
      flop_endr_calc.fim_quadro <= flop_res_accum.fim_quadro;

      if ((signed(flop_coord.coord_x) >= 0) and
          (signed(flop_coord.coord_x) < NUMERO_COLUNAS_IN) and
          (signed(flop_coord.coord_y) >= 0) and
          (signed(flop_coord.coord_y) < NUMERO_LINHAS_IN))then
        flop_endr_calc.dentro_limites <= '1';
        if (test_end_dispo = '1') then
          flop_check_outofBounds.correctAddr <= flop_check_outofBounds.correctAddr + 1;
        end if;
      else
        flop_endr_calc.dentro_limites <= '0';
        if (test_end_dispo = '1') then
          flop_check_outofBounds.outBounds <= flop_check_outofBounds.outBounds + 1;
        end if;
      end if;

      col_mem_addr := unsigned(resize(signed(flop_coord.coord_x), C_LARGURA_ENDR_MEM));
      flop_endr_calc.col_offset
        <= std_logic_vector(col_mem_addr +
                            unsigned(BUFFER_MEM(to_integer(unsigned(curr_buffer))).inicio));

      -- Shift joga fora os bits q sobram
      
      flop_endr_calc.lin_offset <= calcula_offset_linha(calc_offset);

      fim_quadro <= flop_endr_calc.fim_quadro;

    end if;
  end process clk_proc;

  mm_fim_quadro <= fim_quadro;
  -- soma os dois offsets para achar o enereco, poe o endereco do byte 0 se for
  -- borda
  endr_calc_final <= std_logic_vector(unsigned(flop_endr_calc.col_offset) +
                                      unsigned(flop_endr_calc.lin_offset))
                     when flop_endr_calc.dentro_limites = '1' else
                     ADDR_WORD_ZERO;

  -- test_endr_to_fifo <= endr_calc_final;
  
  calc_offset <= signed(flop_coord.coord_y);

  
  flop_coord.coord_x <= (others => '0') when delayed_bits_out(2) = '1' else flop_result_div.div_coord_x;
  flop_coord.coord_y <= (others => '0') when delayed_bits_out(2) = '1' else flop_result_div.div_coord_y;
 
    


  delayed_bits_in(0) <= flop_controle.coord_valida;
  delayed_bits_in(1) <= flop_controle.fim_quadro;
  delayed_bits_in(2) <= '1' when flop_incr_accum.coord_accum_col(2) = zero else '0';
  
  
  --delayed_bits_in(0) <= '1';

  flop_res_accum.coord_valida <= delayed_bits_out(0);
  flop_res_accum.fim_quadro   <= delayed_bits_out(1);
  --test_delay_bit_out <= delayed_bits_out(0);
  mm_endr_disponivel          <= test_end_dispo;

  -- Essa fifo garante que o arbitro possa sempre solicitar um burst
  -- de enderecos da homografia
  fifo_enderecos0 : entity work.fifo_dados
    generic map (
      PROFUNDIDADE_FIFO   => 128,
      LARGURA_FIFO        => C_LARGURA_ENDR_MEM,
      TAMANHO_BURST       => TAMANHO_BURST + CICLOS_LATENCIA, --marreta
      N_BITS_PROFUNDIDADE => 7)
    port map (
      rst_n       => rst_n,
      rd_clk      => mem_clk,
      rd_req      => mm_get_prox_endr,
      rd_vazia    => open,
      rd_burst_en => test_end_dispo,
      data_q      => mm_endr_out,
      wr_clk      => clk,
      -- escreve soh quando a fifo nao estiver cheia
      wr_req      => flop_endr_calc.valido,
      --wr_cheia    => fifo_endr_homog0_cheia,
      wr_cheia    => open,
      wr_burst_en => fifo_endr_wr_burst_en,
      data_d      => endr_calc_final);

---HWs DE DIVISAO
GERA_DIVISOR: if (USA_DIVISOR = 1) generate
  divisor0 : lpm.lpm_components.lpm_divide
    generic map(
      lpm_widthd          => LARGURA_PONTO_MATRIZ_HOMOG,
      lpm_pipeline        => CICLOS_LATENCIA-1,
      lpm_hint            => "MAXIMIZE_SPEED=7, LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_drepresentation => "SIGNED",
      lpm_widthn          => LARGURA_PONTO_MATRIZ_HOMOG)
    port map(
      clock    => clk,
      --remain   : out std_logic_vector (lpm_widthd-1 downto 0);
      clken    => '1',
      numer    => std_logic_vector(flop_incr_accum.coord_accum_col(0)),
      denom    => std_logic_vector(flop_incr_accum.coord_accum_col(2)),
      quotient => flop_result_div.div_coord_x
      );

  divisor1 : lpm.lpm_components.lpm_divide
    generic map(
      lpm_widthd          => LARGURA_PONTO_MATRIZ_HOMOG,
      lpm_pipeline        => CICLOS_LATENCIA-1,
      lpm_hint            => "MAXIMIZE_SPEED=7, LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_drepresentation => "SIGNED",
      lpm_widthn          => LARGURA_PONTO_MATRIZ_HOMOG)
    port map(
      clock    => clk,
      --remain   : out std_logic_vector (lpm_widthd-1 downto 0);
      clken    => '1',
      numer    => std_logic_vector(flop_incr_accum.coord_accum_col(1)),
      denom    => std_logic_vector(flop_incr_accum.coord_accum_col(2)),
      quotient => flop_result_div.div_coord_y
      );
end generate GERA_DIVISOR;

GERA_SHIFTER: if (USA_DIVISOR = 0) generate
  delay_result_x_shifter: entity work.delay_regs(STR)
    generic map(cycles => CICLOS_LATENCIA-1,
                width  => LARGURA_PONTO_MATRIZ_HOMOG)
    port map(clk     => clk,
             rst_n  => rst_n,
             en     => '1',
             input  => std_logic_vector(flop_incr_accum.coord_accum_col(0)),
             output => delayed_x
             );

    delay_result_y_shifter: entity work.delay_regs(STR)
    generic map(cycles => CICLOS_LATENCIA-1,
                width  => LARGURA_PONTO_MATRIZ_HOMOG)
    port map(clk     => clk,
             rst_n  => rst_n,
             en     => '1',
             input  => std_logic_vector(flop_incr_accum.coord_accum_col(1)),
             output => delayed_y
             );

  shifter_right_1: entity work.shifter_right
    generic map (
      WIDTH             => LARGURA_PONTO_MATRIZ_HOMOG,
      CONSTANT_TO_SHIFT => NUMERO_BITS_FRACAO)
    port map (
      signal_unshifted => delayed_x,
      signal_shifted   => flop_result_div.div_coord_x);

  shifter_right_2: entity work.shifter_right
    generic map (
      WIDTH             => LARGURA_PONTO_MATRIZ_HOMOG,
      CONSTANT_TO_SHIFT => NUMERO_BITS_FRACAO)
    port map (
      signal_unshifted => delayed_y,
      signal_shifted   => flop_result_div.div_coord_y);

  
 end generate GERA_SHIFTER;

--PROPAGACAO DO SINAL PELO PIPELINE

  delay_bits : entity work.delay_regs(STR)
    generic map(cycles => CICLOS_LATENCIA-1,
                width  => 3)
    port map(clk     => clk,
             rst_n  => rst_n,
             en     => '1',
             input  => delayed_bits_in,
             output => delayed_bits_out
             );

  --delay_denominador : entity work.delay_regs(STR)
  --  generic map(cycles => CICLOS_LATENCIA-1,
  --              width  => LARGURA_PONTO_MATRIZ_HOMOG)
  --  port map(clk     => clk,
  --            rst_n  => rst_n,
  --            en     => '1',
  --            input  => std_logic_vector(flop_incr_accum.coord_accum_col(2)),
  --            output => delayed_denominador
  --            );



end architecture fpga_arch;
--TODO
--  logica de fim de quadro OK - maomeno
--  logica para preencher pixels fora da faixa (usar uma fifo) - ok
--  normalizacao do resultado da multiplicacao 
--  testbench OK 
--  otimizacao: evitar leituras inuteis !!
