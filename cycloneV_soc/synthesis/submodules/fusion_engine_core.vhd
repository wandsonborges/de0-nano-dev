------------------------------------------------------------------------------
-- Title      : fusion_engine_edge
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fusion_engine_edge.vhd
-- Author     :   <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-10-17
-- Last update: 2019-03-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa toda a engine de fusao:
--              Homografia (Atualizada), calculo de histograma, mutual information e fusao
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 2013-10-17  1.0      mdrumond                Created
-- 2014-08-15  1.1      rodrigo.oliveira        Update // OBS: Homografia em ambas as imagens
-- 2017-10-24  1.3      fernando.daldegan       Update -> Incluido controle pelo menu
-- 2017-10-30  1.4      rodrigo.oliveira        Update -> Nova Matriz SR
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uteis.all;

LIBRARY altera_mf;
USE altera_mf.all;

--use work.hist_definitions_pkg.all;

entity fusion_engine_ddr2 is
  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    NUMERO_LINHAS            : integer := 256;
    LARGURA_CONTADOR_LINHAS  : integer := 9;
    LARGURA_ITERACOES        : integer := 4;
    NUMERO_ITERACOES         : integer := 8;
    --LARGURA_ITERACOES        : integer := 1;
    --NUMERO_ITERACOES         : integer := 2;
    LARGURA_PASSO            : integer := 1;
    LARGURA_BINS             : integer := 16;
    LARGURA_ADDR_BINS        : integer := 4;
    LARGURA_N_HISTOGRAMAS    : integer := 2
    );
  port (
    rst_n            : in std_logic;
    sys_clk          : in std_logic;
    mem_clk          : in std_logic;
    float_img_comeca : in std_logic;
    fixed_img_comeca : in std_logic;

    float_img_port_buffer_id : in  buffer_id_t;
    float_img_port_data      : in  word_mem_t;
    float_img_port_addr      : out endr_mem_t;
    float_img_port_rd_en     : out std_logic;
    float_img_port_addr_disp : out std_logic;
    float_img_port_addr_req  : in  std_logic;
    float_img_port_burst_en  : in  std_logic;

    fixed_img_port_buffer_id : in  buffer_id_t;
    fixed_img_port_data      : in  word_mem_t;
    fixed_img_port_addr      : out endr_mem_t;
    fixed_img_port_rd_en     : out std_logic;
    fixed_img_port_addr_disp : out std_logic;
    fixed_img_port_addr_req  : in  std_logic;
    fixed_img_port_burst_en  : in  std_logic;

    fusao_wr_port_buffer_id : out buffer_id_t;
    fusao_wr_port_data      : out word_mem_t;
    fusao_wr_port_addr      : out endr_mem_t;
    fusao_wr_port_wr_en     : out std_logic;
    fusao_wr_port_addr_disp : out std_logic;
    fusao_wr_port_addr_req  : in  std_logic;
    fusao_wr_port_burst_en  : in  std_logic;

    brilho_offset        : in std_logic_vector(7 downto 0);
    jtag_tipo_fusao      : in std_logic_vector(1 downto 0);
    norma_threshold      : in std_logic_vector(C_LARGURA_PIXEL+2-1 downto 0);
    matriz_homog_wr_data : in std_logic_vector(31 downto 0);
    matriz_homog_wr_en   : in std_logic;

    clear     : in  std_logic;
    end_frame : out std_logic;
    ent_valid : out std_logic;
    mi_valid  : out std_logic;
    ent_data  : out std_logic_vector(LARGURA_BINS + LARGURA_ADDR_BINS + 4 +4 + 1-1 downto 0);
    mi_data   : out std_logic_vector(LARGURA_BINS + LARGURA_ADDR_BINS + 4 +4 + 1-1 downto 0);
    
    escolhe_metodo_registro : in std_logic_vector(1 downto 0);
    enable_reg_lut          : in std_logic_vector(0 downto 0);
    register_offset         : in std_logic_vector(7 downto 0);
    escolhe_metodo_fusao    : in std_logic_vector(1 downto 0);
    alpha                   : in std_logic_vector(7 downto 0);
    pallete_select          : in std_logic_vector(1 downto 0);
    threshold_thermal       : in pixel_t;

    current_offset    : out std_logic_vector(7 downto 0);
    current_alpha     : out std_logic_vector(7 downto 0);
    current_threshold : out std_logic_vector(7 downto 0)
    );
end entity fusion_engine_ddr2;

architecture fpga of fusion_engine_ddr2 is
  constant PROFUNDIDADE_FIFO   : integer := 512;
  constant LARGURA_FIFO        : integer := 16;
  constant TAMANHO_BURST       : integer := 16;
  constant N_BITS_PROFUNDIDADE : integer := 9;

  constant NUMERO_HISTOGRAMAS   : integer := 2**LARGURA_N_HISTOGRAMAS;
  constant NUMERO_TAMANHO_PASSO : integer := 2**LARGURA_PASSO;
  constant NUMERO_PIXEIS_EXTRAS : integer := (NUMERO_ITERACOES * NUMERO_HISTOGRAMAS - 1) * NUMERO_TAMANHO_PASSO;

  signal mm_comeca_quadro_ir   : std_logic;
  signal mm_curr_buffer_in_ir  : buffer_id_t;
  signal mm_get_prox_endr_ir   : std_logic;
  signal mm_fim_quadro_ir      : std_logic;
  signal mm_endr_out_ir        : endr_mem_t;
  signal mm_endr_disponivel_ir : std_logic;

  signal mm_comeca_quadro_sr   : std_logic;
  signal mm_curr_buffer_in_sr  : buffer_id_t;
  signal mm_get_prox_endr_sr   : std_logic;
  signal mm_fim_quadro_sr      : std_logic;
  signal mm_endr_out_sr        : endr_mem_t;
  signal mm_endr_disponivel_sr : std_logic;

  signal offset_jtag            : std_logic_vector(7 downto 0) := (others => '0');
  signal offset_jtag_y          : std_logic_vector(31 downto 0) := (others => '0');
  signal pallete_select_jtag    : std_logic_vector(1 downto 0);
  signal threshold_thermal_jtag : std_logic_vector(7 downto 0);
  signal fusion_type_jtag       : std_logic_vector(1 downto 0);
  signal alpha_jtag             : std_logic_vector(7 downto 0);


  -----------------------------------------------------------------------------
  -- matriz_ir : 10.15 fixed point
  --constant MATRIZ_HOMOG_IR : matriz_homog_t :=
  --  ((std_logic_vector(to_signed(     15503, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(      -525, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1757140, LARGURA_PONTO_MATRIZ))),

  --   (std_logic_vector(to_signed(       730, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(     16393, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   2272853, LARGURA_PONTO_MATRIZ))),

  --   (std_logic_vector(to_signed(         1, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(        -1, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(     29067, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --
  constant MATRIZ_HOMOG_IR : matriz_homog_t :=
    ((std_logic_vector(to_signed(     17499, LARGURA_PONTO_MATRIZ)),  --15499
      std_logic_vector(to_signed(      -526, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(   1608021, LARGURA_PONTO_MATRIZ))), --1768021

     (std_logic_vector(to_signed(       533, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     18398, LARGURA_PONTO_MATRIZ)),  --16398
      std_logic_vector(to_signed(     59684, LARGURA_PONTO_MATRIZ))), --2259684

     (std_logic_vector(to_signed(         1, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(        -1, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     29067, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  -- ID SEM DIVISOR
  constant MATRIZ_HOMOG_IR_ID : matriz_homog_t :=
    ((std_logic_vector(to_signed(      1024, LARGURA_PONTO_MATRIZ)),  --15499
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ))), --1768021

     (std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(      1024, LARGURA_PONTO_MATRIZ)),  --16398
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ))), --2259684

     (std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(      1024, LARGURA_PONTO_MATRIZ))) );
  
  -----------------------------------------------------------------------------
  -- matriz_sr : 19.8 fixed point
  --constant MATRIZ_HOMOG_SR : matriz_homog_t :=
  --  ((std_logic_vector(to_signed(   -201720, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(       -83, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1529224, LARGURA_PONTO_MATRIZ))),

  --   (std_logic_vector(to_signed(     -2868, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   -201094, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1503355, LARGURA_PONTO_MATRIZ)) ),

  --   (std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   -199674, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  -- matriz_sr : 11.15 fixed point SHIFTER
  -- constant MATRIZ_HOMOG_SR : matriz_homog_t := 
  --   ((std_logic_vector(to_signed(     28842, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(       281, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(    425310, LARGURA_PONTO_MATRIZ))),
     
  --    (std_logic_vector(to_signed(       -75, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(     29374, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(    878430, LARGURA_PONTO_MATRIZ))),

  --    (std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(         5, LARGURA_PONTO_MATRIZ)),
  --     std_logic_vector(to_signed(     32921, LARGURA_PONTO_MATRIZ))) );

  -- constant MATRIZ_HOMOG_SR : matriz_homog_t := -- 30/10/17
  --                                              ((std_logic_vector(to_signed(29379, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(2, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(674533, LARGURA_PONTO_MATRIZ))),
  --                                               (std_logic_vector(to_signed(168, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(29235, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(740100, LARGURA_PONTO_MATRIZ))),
  --                                               (std_logic_vector(to_signed(1, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(2, LARGURA_PONTO_MATRIZ)),
  --                                                std_logic_vector(to_signed(32874, LARGURA_PONTO_MATRIZ))) );

    constant MATRIZ_HOMOG_SR : matriz_homog_t := -- 18/05/18
((std_logic_vector(to_signed(11955, LARGURA_PONTO_MATRIZ)),
 std_logic_vector(to_signed(-816, LARGURA_PONTO_MATRIZ)),
 std_logic_vector(to_signed(3753676, LARGURA_PONTO_MATRIZ))),
  (std_logic_vector(to_signed(-307, LARGURA_PONTO_MATRIZ)),
  std_logic_vector(to_signed(11925, LARGURA_PONTO_MATRIZ)),
  std_logic_vector(to_signed(2517233, LARGURA_PONTO_MATRIZ))),
  (std_logic_vector(to_signed(-2, LARGURA_PONTO_MATRIZ)),
   std_logic_vector(to_signed(-3, LARGURA_PONTO_MATRIZ)),
   std_logic_vector(to_signed(31034, LARGURA_PONTO_MATRIZ))) );


  -----------------------------------------------------------------------------
  -- MATRIZ SWIR -> IR DIRETO. SEM DIVISOR 11.11 FIXED POINT
  constant MATRIZ_HOMOG_SWIR_SEM_DIV : matriz_homog_t :=
    ((std_logic_vector(to_signed(      1367, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(       -10, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(    107054, LARGURA_PONTO_MATRIZ))),

     (std_logic_vector(to_signed(       -19, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(      1237, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(    150492, LARGURA_PONTO_MATRIZ)) ),

     (std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(      2048, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --11.21
  --constant MATRIZ_HOMOG_SWIR_COM_DIV : matriz_homog_t :=
  --  ((std_logic_vector(to_signed(   1540509, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(     67451, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ))), --std_logic_vector(to_signed(14722773, LARGURA_PONTO_MATRIZ))),

  --   (std_logic_vector(to_signed(     20901, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1429616, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed( 150632480, LARGURA_PONTO_MATRIZ)) ),

  --   (std_logic_vector(to_signed(       193, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(       458, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   2146379, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --
  constant MATRIZ_HOMOG_SWIR_COM_DIV : matriz_homog_t :=
    ((std_logic_vector(to_signed(   1542460, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     72153, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(  82588312, LARGURA_PONTO_MATRIZ))), --std_logic_vector(to_signed(14722773, LARGURA_PONTO_MATRIZ))),

     (std_logic_vector(to_signed(     21007, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(   1429866, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed( 152433744, LARGURA_PONTO_MATRIZ)) ),

     (std_logic_vector(to_signed(       194, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(       460, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(   2163094, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --
  constant MATRIZ_HOMOG_SWIR_GARCIA : matriz_homog_t :=
    ((std_logic_vector(to_signed(    712211, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     -7479, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(  30688188, LARGURA_PONTO_MATRIZ))), --std_logic_vector(to_signed(14722773, LARGURA_PONTO_MATRIZ))),

     (std_logic_vector(to_signed(     10710, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(    646039, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(  75919664, LARGURA_PONTO_MATRIZ)) ),

     (std_logic_vector(to_signed(        57, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(       -33, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(   1056493, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --
  --constant MATRIZ_HOMOG_SWIR_ROBOT : matriz_homog_t :=
  --  ((std_logic_vector(to_signed(    712646, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(     -6420, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(  16846939, LARGURA_PONTO_MATRIZ))), --std_logic_vector(to_signed(14722773, LARGURA_PONTO_MATRIZ))),

  --   (std_logic_vector(to_signed(      8340, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(    640654, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(  75675272, LARGURA_PONTO_MATRIZ)) ),

  --   (std_logic_vector(to_signed(        49, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(       -58, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1051037, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --11.21
  --constant MATRIZ_HOMOG_SWIR_ROBOT : matriz_homog_t :=
  --  ((std_logic_vector(to_signed(    728067, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(     -9650, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(  21838648, LARGURA_PONTO_MATRIZ))),
  --
  --   (std_logic_vector(to_signed(     17806, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(    660802, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(  48801020, LARGURA_PONTO_MATRIZ))),
  --
  --   (std_logic_vector(to_signed(        65, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(         5, LARGURA_PONTO_MATRIZ)),
  --    std_logic_vector(to_signed(   1060459, LARGURA_PONTO_MATRIZ))) );

  -----------------------------------------------------------------------------
  --11.15
  constant MATRIZ_HOMOG_SWIR_ROBOT : matriz_homog_t :=
    ((std_logic_vector(to_signed(     22752, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(      -301, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(    682457, LARGURA_PONTO_MATRIZ))),

     (std_logic_vector(to_signed(       556, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     20650, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(   1556281, LARGURA_PONTO_MATRIZ))),

     (std_logic_vector(to_signed(         2, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(         0, LARGURA_PONTO_MATRIZ)),
      std_logic_vector(to_signed(     33139, LARGURA_PONTO_MATRIZ))) );
  
  -----------------------------------------------------------------------------
  signal matriz_homog_ir_out : matriz_homog_t := MATRIZ_HOMOG_IR;
  signal matriz_homo_ir      : matriz_homog_t := MATRIZ_HOMOG_IR;
  signal matriz_homog_sr_out : matriz_homog_t := MATRIZ_HOMOG_SR;
  signal matriz_homo_sr      : matriz_homog_t := MATRIZ_HOMOG_SR;
  
  -----------------------------------------------------------------------------
  signal endr_fixed_in_in  : endr_gen_in_t;
  signal endr_fusao_wr_in  : endr_gen_in_t;
  signal endr_fixed_in_out : endr_gen_out_t;
  signal endr_fusao_wr_out : endr_gen_out_t;
  
  -----------------------------------------------------------------------------
  signal fxd_pix_in          : pixel_t;
  signal flt_pix_in          : pixel_t;
  signal reg_start_frame     : std_logic;
  signal reg_end_frame       : std_logic;
  signal fxd_pix_rd_req      : std_logic;
  signal flt_pix_rd_req      : std_logic;
  signal fxd_pix_rd_burst_en : std_logic;
  signal flt_pix_rd_burst_en : std_logic;
  signal fxd_pix_out         : pixel_t;
  signal flt_pix_out         : pixel_t;
  signal fxd_pix_wr_req      : std_logic;
  signal flt_pix_wr_req      : std_logic;
  signal x_offset            : std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);
  signal offset_shifter      : std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);

  signal fxd_pix_in_i : std_logic_vector(15 downto 0);
  signal flt_pix_in_i : std_logic_vector(15 downto 0);

  -----------------------------------------------------------------------------
  signal pixel_flt_align_out   : std_logic_vector(C_LARGURA_PIXEL-1 downto 0);
  signal pixel_fxd_align_out   : std_logic_vector(C_LARGURA_PIXEL-1 downto 0);
  signal pixel_align_valid_out : std_logic;
  
  -----------------------------------------------------------------------------
  signal pixel_flt_hist_eq_out       : std_logic_vector(C_LARGURA_PIXEL-1 downto 0);
  signal pixel_flt_hist_eq_valid_out : std_logic;

  -----------------------------------------------------------------------------
  signal float_img_comeca_f1 : std_logic := '0';
  signal float_img_comeca_f2 : std_logic := '0';
  signal fixed_img_comeca_f1 : std_logic := '0';
  signal fixed_img_comeca_f2 : std_logic := '0';
  
  ----------------------------------------------------------------------------
  signal marca_enable : std_logic; -- := '0';
  signal test_pixel   : std_logic_vector(15 downto 0);
  signal fusao_wr_en  : std_logic;

  ----------------------------------------------------------------------------
  type TYPE_OFFSET_GRADE is array (0 to (2**2)-1) of NATURAL;
  constant OFFSET_LUT : TYPE_OFFSET_GRADE := (
    0 => 23, -- 5.00 m
    1 => 26, -- 4.00 m
    2 => 29, -- 3.00 m
    3 => 38  -- 2.00 m
    );
  
  signal enable_reg_lut_i          : std_logic_vector(         enable_reg_lut'length - 1 downto 0);
  signal register_offset_i         : std_logic_vector(        register_offset'length - 1 downto 0);
  signal escolhe_metodo_registro_i : std_logic_vector(escolhe_metodo_registro'length - 1 downto 0);
  ----------------------------------------------------------------------------

begin  -- architecture fpga

  matriz_homo_sr(1)(2) <= std_logic_vector(to_signed(2517233 - 196608, LARGURA_PONTO_MATRIZ) +
                                            signed(offset_jtag_y));-- + signed(x"fffd0000"));
  ----------------------------------------------------------------------------
  dFfVectorSynchronizer_1 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => enable_reg_lut'length
      )
    port map (
      nReset => rst_n,
      clock  => sys_clk,
      input  => enable_reg_lut,
      output => enable_reg_lut_i
      );

  dFfVectorSynchronizer_2 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => register_offset'length
      )
    port map (
      nReset => rst_n,
      clock  => sys_clk,
      input  => register_offset,
      output => register_offset_i
      );

  dFfVectorSynchronizer_3 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => escolhe_metodo_registro'length
      )
    port map (
      nReset => rst_n,
      clock  => sys_clk,
      input  => escolhe_metodo_registro,
      output => escolhe_metodo_registro_i
      );
  
  -----------------------------------------------------------------------------
  -- Flopa os sinais de inicio de frame
  -----------------------------------------------------------------------------
  -- purpose: Flopa os estados para evitar metaestabilidade
  -- type   : sequential
  -- inputs : sys_clk, rst_n
  -- outputs: 
  clk_proc : process (sys_clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      float_img_comeca_f1 <= '0';
      float_img_comeca_f2 <= '0';

      fixed_img_comeca_f1 <= '0';
      fixed_img_comeca_f2 <= '0';
      
    elsif sys_clk'event and sys_clk = '1' then  -- rising clock edge
      float_img_comeca_f1 <= float_img_comeca;
      float_img_comeca_f2 <= float_img_comeca_f1;

      fixed_img_comeca_f1 <= fixed_img_comeca;
      fixed_img_comeca_f2 <= fixed_img_comeca_f1;

    end if;
  end process clk_proc;

  -----------------------------------------------------------------------------
  -- Homografia da imagem ir (altera a escala, perspectiva e adiciona
  -- offsets em x e y)
  -----------------------------------------------------------------------------
  -- preenche_matriz_homog_ir : entity work.preenche_matriz_homog
  --   generic map (
  --     DEF_MATRIZ_HOMOG_IN     => MATRIZ_HOMOG_IR_ID,
  --     BIT_HOMOG_WR_DATA_WR_EN => 31
  --     )
  --   port map (
  --     sys_clk              => sys_clk,
  --     rst_n                => rst_n,
  --     matriz_homog_wr_data => matriz_homog_wr_data,
  --     matriz_homog_wr_en   => matriz_homog_wr_en,
  --     matriz_homog_out     => matriz_homo_ir,
  --     mm_fim_quadro        => mm_fim_quadro_ir
  --     );

  mult_matriz_ir : entity work.mult_matriz_v1
    generic map (
      DEF_MATRIZ_HOMOG_IN     => MATRIZ_HOMOG_IR_ID,
      TAMANHO_BURST           => TAMANHO_BURST,
      NUMERO_COLUNAS_IN       => NUMERO_COLUNAS,
      NUMERO_COLUNAS_OUT      => NUMERO_COLUNAS, -- + NUMERO_PIXEIS_EXTRAS,
      LARGURA_CONTADOR_COLUNA => LARGURA_CONTADOR_COLUNAS,
      NUMERO_LINHAS_IN        => NUMERO_LINHAS,
      NUMERO_LINHAS_OUT       => NUMERO_LINHAS,
      NUMERO_BITS_INTEIRO     => LARGURA_INT_PONTO_MATRIZ_HOMOG_IR_ID,
      NUMERO_BITS_FRACAO      => LARGURA_FRAC_PONTO_MATRIZ_HOMOG_IR_ID,
      USA_DIVISOR             => 0, 
      LARGURA_CONTADOR_LINHA  => LARGURA_CONTADOR_LINHAS,
      BUFFER_MEM              => MEM_MAP_BUFFER_DEFAULT
      )
    port map (
      mem_clk            => mem_clk,
      clk                => sys_clk,
      rst_n              => rst_n,
      mm_comeca_quadro   => mm_comeca_quadro_ir,
      matriz_homo        => matriz_homo_ir,
      mm_curr_buffer_in  => mm_curr_buffer_in_ir,
      mm_get_prox_endr   => mm_get_prox_endr_ir,
      mm_fim_quadro      => mm_fim_quadro_ir,
      mm_endr_out        => mm_endr_out_ir,
      mm_endr_disponivel => mm_endr_disponivel_ir
      );

  mm_comeca_quadro_ir      <= '1';
  mm_curr_buffer_in_ir     <= fixed_img_port_buffer_id;
  mm_get_prox_endr_ir      <= fixed_img_port_addr_req;
  fixed_img_port_addr      <= mm_endr_out_ir;
  fixed_img_port_addr_disp <= mm_endr_disponivel_ir;

  fixed_img_port_rd_en <= fxd_pix_rd_req;
  fxd_pix_in           <= fixed_img_port_data(13 downto 6); --fixed_img_port_data(C_LARGURA_PIXEL-1 downto 0);
  fxd_pix_rd_burst_en  <= fixed_img_port_burst_en;

  --------------------------------------------------------------------------------
  -- HOMOGRAFIA SENSOR SR
   -----------------------------------------------------------------------------------
  -- preenche_matriz_homog_sr : entity work.preenche_matriz_homog
  --   generic map (
  --     DEF_MATRIZ_HOMOG_IN     => MATRIZ_HOMOG_SR,
  --     BIT_HOMOG_WR_DATA_WR_EN => 30
  --     )
  --   port map (
  --     sys_clk              => sys_clk,
  --     rst_n                => rst_n,
  --     matriz_homog_wr_data => matriz_homog_wr_data,
  --     matriz_homog_wr_en   => matriz_homog_wr_en,
  --     matriz_homog_out     => open, --matriz_homo_sr,
  --     mm_fim_quadro        => mm_fim_quadro_sr
  --     );

  mult_matriz_sr : entity work.mult_matriz_v1
    generic map (
      DEF_MATRIZ_HOMOG_IN     => MATRIZ_HOMOG_SR, --MATRIZ_HOMOG_SWIR_ROBOT,
      TAMANHO_BURST           => TAMANHO_BURST,
      NUMERO_COLUNAS_IN       => NUMERO_COLUNAS,
      NUMERO_COLUNAS_OUT      => NUMERO_COLUNAS + NUMERO_PIXEIS_EXTRAS,
      LARGURA_CONTADOR_COLUNA => LARGURA_CONTADOR_COLUNAS,
      NUMERO_LINHAS_IN        => NUMERO_LINHAS,
      NUMERO_LINHAS_OUT       => NUMERO_LINHAS,
      NUMERO_BITS_INTEIRO     => LARGURA_INT_PONTO_MATRIZ_HOMOG_SWIR,
      NUMERO_BITS_FRACAO      => LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SWIR,
      USA_DIVISOR             => 1,
      LARGURA_CONTADOR_LINHA  => LARGURA_CONTADOR_LINHAS,
      BUFFER_MEM              => MEM_MAP_BUFFER_DEFAULT
      )
    port map (
      mem_clk            => mem_clk,
      clk                => sys_clk,
      rst_n              => rst_n,
      mm_comeca_quadro   => mm_comeca_quadro_sr,
      matriz_homo        => matriz_homo_sr,
      mm_curr_buffer_in  => mm_curr_buffer_in_sr,
      mm_get_prox_endr   => mm_get_prox_endr_sr,
      mm_fim_quadro      => mm_fim_quadro_sr,
      mm_endr_out        => mm_endr_out_sr,
      mm_endr_disponivel => mm_endr_disponivel_sr
      );

  mm_comeca_quadro_sr      <= '1';
  mm_curr_buffer_in_sr     <= (others => '0');  --fixed_img_port_buffer_id;
  mm_get_prox_endr_sr      <= float_img_port_addr_req;
  float_img_port_addr      <= mm_endr_out_sr;
  float_img_port_addr_disp <= mm_endr_disponivel_sr;

  float_img_port_rd_en <= flt_pix_rd_req;
  flt_pix_in           <= float_img_port_data(C_LARGURA_PIXEL-1 downto 0);
  flt_pix_rd_burst_en  <= float_img_port_burst_en;

  -------------------------------------------------------------------------
  -- Segundo passo, executa o sobel nas duas imagens e calcula a entropia
  -------------------------------------------------------------------------
  reg_start_frame <= fixed_img_comeca_f2 or float_img_comeca_f2;
  registration_1 : entity work.registration
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS,
      NUMERO_LINHAS            => NUMERO_LINHAS,
      LARGURA_CONTADOR_LINHAS  => LARGURA_CONTADOR_LINHAS,
      LARGURA_N_HISTOGRAMAS    => LARGURA_N_HISTOGRAMAS,
      LARGURA_ITERACOES        => LARGURA_ITERACOES,
      NUMERO_ITERACOES         => NUMERO_ITERACOES,
      LARGURA_PASSO            => LARGURA_PASSO,
      LARGURA_BINS             => LARGURA_BINS,
      LARGURA_ADDR_BINS        => LARGURA_ADDR_BINS
      )
    port map (
      clk                   => sys_clk,
      rst_n                 => rst_n,
      start_frame           => reg_start_frame,
      end_frame             => reg_end_frame,
      fxd_pix_in            => fxd_pix_in,
      flt_pix_in            => flt_pix_in,
      fxd_pix_rd_req        => fxd_pix_rd_req,
      flt_pix_rd_req        => flt_pix_rd_req,
      fxd_pix_rd_burst_en   => fxd_pix_rd_burst_en,
      flt_pix_rd_burst_en   => flt_pix_rd_burst_en,
      fxd_pix_out           => fxd_pix_out,
      flt_pix_out           => flt_pix_out,
      fxd_pix_wr_req        => fxd_pix_wr_req,
      flt_pix_wr_req        => flt_pix_wr_req,
      fusao_pix_wr_burst_en => fusao_wr_port_burst_en,
      offset                => x_offset,
      norma_threshold       => norma_threshold,
      escolhe_metodo        => escolhe_metodo_registro_i,
      ent_data              => ent_data,
      ent_valid             => ent_valid,
      mi_data               => mi_data,
      mi_valid              => mi_valid
      );

  -------------------------------------------------------------------------
  -- Terceiro passo calcula o histograma e o mutual information
  -------------------------------------------------------------------------
  --hist_equalization_1 : entity work.hist_equalization
  --  generic map (
  --    PIXEL_WIDTH      => C_LARGURA_PIXEL,
  --    IMAGE_SIZE_WIDTH => 17,
  --    IMAGE_SIZE       => (NUMERO_COLUNAS + NUMERO_PIXEIS_EXTRAS)*NUMERO_LINHAS
  --    )
  --  port map (
  --    clk             => sys_clk,
  --    rst_n           => rst_n,
  --    pixel_in        => flt_pix_out,
  --    pixel_in_valid  => flt_pix_wr_req,
  --    pixel_out       => pixel_flt_hist_eq_out,
  --    pixel_out_valid => pixel_flt_hist_eq_valid_out,
  --    up_lut_strt     => reg_end_frame,
  --    up_lut_done     => open,
  --    lut_en          => '0'
  --    );

  end_frame      <= reg_end_frame;


  -- daldegan
  --offset_shifter <= register_offset_i(LARGURA_CONTADOR_COLUNAS-1 downto 0);
  --offset_shifter <= register_offset_i(LARGURA_CONTADOR_COLUNAS-1 downto 0)
  --                  when register_offset_i(LARGURA_CONTADOR_COLUNAS) = '1' else
  --                  '0' & x"2e";

  current_offset <= offset_shifter(7 downto 0);
  offset_shifter <= -- Registro manual sem LUT
                    STD_LOGIC_VECTOR(RESIZE(UNSIGNED(register_offset_i), LARGURA_CONTADOR_COLUNAS))
                      when ((escolhe_metodo_registro_i = "00") and (enable_reg_lut_i = "0")) else
                    -----------------------------------------------------------
                    -- Registro manual com LUT
                    STD_LOGIC_VECTOR(TO_UNSIGNED(OFFSET_LUT(TO_INTEGER(UNSIGNED(register_offset_i))), LARGURA_CONTADOR_COLUNAS))
                      when ((escolhe_metodo_registro_i = "00") and (enable_reg_lut_i = "1")) else
                    -----------------------------------------------------------
                    -- Registro dinamico travado
                    STD_LOGIC_VECTOR(RESIZE(UNSIGNED(register_offset_i)/2, LARGURA_CONTADOR_COLUNAS))
                      when ((escolhe_metodo_registro_i /= "00") and (register_offset_i(0) = '1')) else
                    -----------------------------------------------------------
                    -- Registro dinamico livre
                    x_offset;
  
  img_aligner_1 : entity work.img_aligner
    generic map (
      TAMANHO_LINHA_IN    => NUMERO_COLUNAS + NUMERO_PIXEIS_EXTRAS,
      --TAMANHO_LINHA_IN    => NUMERO_COLUNAS,
      TAMANHO_LINHA_OUT   => NUMERO_COLUNAS,
      N_BITS_ENDR_LINHA   => LARGURA_CONTADOR_COLUNAS,
      PROFUNDIDADE_FIFO   => PROFUNDIDADE_FIFO,
      N_BITS_PROFUNDIDADE => N_BITS_PROFUNDIDADE,
      LARGURA_PIXEL       => 8,
      TAMANHO_BURST       => TAMANHO_BURST
      )
    port map (
      clk                    => sys_clk,
      rst_n                  => rst_n,
      x_offset               => offset_shifter, --offset_jtag,
      pixel_flt_align_in     => flt_pix_in,     --pixel_flt_hist_eq_out,
      pixel_fxd_align_in     => fxd_pix_out,
      pixel_flt_align_wr_req => flt_pix_wr_req, --pixel_flt_hist_eq_valid_out,
      pixel_fxd_align_wr_req => fxd_pix_wr_req,
      pixel_flt_align_out    => pixel_flt_align_out,
      pixel_fxd_align_out    => pixel_fxd_align_out,
      pixel_align_valid_out  => pixel_align_valid_out
      );

  -------------------------------------------------------------------------
  -- Quarto passo executa a fusao
  -------------------------------------------------------------------------
  fusao_1 : entity work.fusao
    port map (
      clk                  => sys_clk,
      rst_n                => rst_n,
      pixel_fxd_fusao_in   => pixel_flt_align_out,
      pixel_flt_fusao_in   => pixel_fxd_align_out,
      pixel_fusao_valid_in => pixel_align_valid_out,
      tipo_fusao           => escolhe_metodo_fusao, --'0',
      threshold            => threshold_thermal, --threshold_thermal_jtag,
      alpha                => alpha,
      brilho_offset        => brilho_offset,
      pallete_select       => pallete_select,
      --jtag_tipo_fusao      => fusion_type_jtag, --jtag_tipo_fusao,
      clear                => clear,
      current_alpha        => current_alpha,
      current_threshold    => current_threshold,
      fusao_out_wr_req     => fusao_wr_en,
      pixel_fusao_out      => fusao_wr_port_data
      );

  fusao_wr_port_wr_en <= fusao_wr_en;

  endr_gen_fusao_out : entity work.endr_gen
    generic map (
      BUFF_MAP   => MEM_MAP_BUFFER_DEFAULT,
      BURST_SIZE => 8
      )
    port map (
      clk          => mem_clk,
      rst_n        => rst_n,
      endr_gen_in  => endr_fusao_wr_in,
      endr_gen_out => endr_fusao_wr_out
      );

  endr_fusao_wr_in.buff_atual_in_en <= '0';
  endr_fusao_wr_in.rst_endr         <= '0';
  endr_fusao_wr_in.prox_endr        <= fusao_wr_port_addr_req;

  fusao_wr_port_addr_disp <= '1';
  fusao_wr_port_addr      <= endr_fusao_wr_out.endr_out;
  fusao_wr_port_buffer_id <= endr_fusao_wr_in.buff_atual_in;

  -----------------------------------------------------------------------------
  -- CONFIG FUSAO - JTAG
  -----------------------------------------------------------------------------
  altsource_probe_component_offset_fus : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fOff",
     probe_width => 8,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => '0' & x"2E",
     source_width => 8,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => offset_jtag,
     source_clk => sys_clk,
     source_ena => '1',
     source => offset_jtag
     );

    altsource_probe_component_offset_fusy : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fOfy",
     probe_width => 8,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => x"00000000",
     source_width => 32,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => offset_jtag,
     source_clk => sys_clk,
     source_ena => '1',
     source => offset_jtag_y
     );

  altsource_probe_component_tipo_fusao : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fTyp",
     probe_width => 1,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => "01",
     source_width => 2,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => enable_reg_lut,
     source_clk => sys_clk,
     source_ena => '1',
     source => fusion_type_jtag
     );

  altsource_probe_component_threshold_fusao : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fThr",
     probe_width => 1,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => "0",
     source_width => 8,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => enable_reg_lut,
     source_clk => sys_clk,
     source_ena => '1',
     source => threshold_thermal_jtag
     );

  altsource_probe_component_pallete_fusao : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fPal",
     probe_width => 1,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => "00",
     source_width => 2,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => enable_reg_lut,
     source_clk => sys_clk,
     source_ena => '1',
     source => pallete_select_jtag
     );  
  
  altsource_probe_component_alpha_fusao : altera_mf.altera_mf_components.altsource_probe
   GENERIC MAP (
     enable_metastability => "YES",
     instance_id => "fAlp",
     probe_width => 1,
     sld_auto_instance_index => "YES",
     sld_instance_index => 0,
     source_initial_value => "00",
     source_width => 8,
     lpm_type => "altsource_probe"
     )
   PORT MAP (
     probe => enable_reg_lut,
     source_clk => sys_clk,
     source_ena => '1',
     source => alpha_jtag
     );

  --daldegan: liga registro dinamico
  -- altsource_probe_component_demo_mode : altera_mf.altera_mf_components.altsource_probe
  --  GENERIC MAP (
  --    enable_metastability => "YES",
  --    instance_id => "demo",
  --    probe_width => 1,
  --    sld_auto_instance_index => "YES",
  --    sld_instance_index => 0,
  --    source_initial_value => "00",
  --    source_width => 2,
  --    lpm_type => "altsource_probe"
  --    )
  --  PORT MAP (
  --    probe => enable_reg_lut,
  --    source_clk => sys_clk,
  --    source_ena => '1',
  --    source => demo_mode_jtag
  --    );

  -----------------------------------------------------------------------------
  
end architecture fpga;
