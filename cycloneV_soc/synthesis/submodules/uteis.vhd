-------------------------------------------------------------------------------
-- Title      : uteis
-- Project    : 
-------------------------------------------------------------------------------
-- File       : uteis.vhd
-- Author     : mdrumond  <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-08-21
-- Last update: 2019-03-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Pacote com utilidades: tipos, e procedures e constantes
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-08-21  1.0      mdrumond        Created
-- 2014-09-04  1.1      rodrigo.oliveira Updated  Parametrizacao bits
-- fracao/inteiro para realizacao da homografia
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package uteis is

  constant C_LARGURA_WORD_MEM : positive := 16;
  constant C_LARGURA_ENDR_MEM : positive := 32;

  constant C_LARGURA_PIXEL : positive := 8;

  constant C_LARGURA_MULT_IN  : positive := 18;
  constant C_LARGURA_MULT_OUT : positive := 36;

  component multiplexador_one_hot is
    generic (
      LARGURA_PALAVRA : integer;
      NUMERO_PALAVRAS : INTEGER
      );
    port (
      data_in  : in  std_logic_vector(LARGURA_PALAVRA*NUMERO_PALAVRAS-1 downto 0);
      data_out : out std_logic_vector(LARGURA_PALAVRA-1 downto 0);
      data_sl  : in  std_logic_vector(NUMERO_PALAVRAS-1 downto 0)
      );
  end component multiplexador_one_hot;

  component clock_buffer is
    port (
      clk_in  : in  std_logic;
      clk_out : out std_logic;
      clk_en  : in  std_logic := '1'
      );
  end component clock_buffer;

  component Video_Decoder_Adv7180 is
    port (
      clk       : in    std_logic;
      nrst      : in    std_logic;
      vsync_in  : in    std_logic;
      href_in   : in    std_logic;
      data_in   : in    std_logic_vector(7 downto 0);
      sda       : inout std_logic;
      nrst_dec  : out   std_logic;
      scl       : out   std_logic;
      end_frame : out   std_logic;
      data_out  : out   std_logic_vector(7 downto 0)
      );
  end component Video_Decoder_Adv7180;

  -----------------------------------------------------------------------------
  -- Tipos de dados gerais
  -----------------------------------------------------------------------------
  subtype pixel_t    is std_logic_vector(C_LARGURA_PIXEL    - 1 downto 0);
  subtype endr_mem_t is std_logic_vector(C_LARGURA_ENDR_MEM - 1 downto 0);
  subtype word_mem_t is std_logic_vector(C_LARGURA_WORD_MEM - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Mapa de memoria
  -----------------------------------------------------------------------------
  type buffer_mem_t is record
    inicio, fim : endr_mem_t;
    troca       : endr_mem_t;
  end record buffer_mem_t;

  constant NUM_BUFFERS : positive := 2;

  type buffer_ping_pong_t is array (0 to NUM_BUFFERS-1) of buffer_mem_t;
  -- Buffers recebe o nome do modulo que escrevem nele
  -- inicio: inicio do buffer
  -- fim : fim do buffer
  -- troca: endereco onde o dispositivo que escreve sinaliza o
  -- buffer como pronto
  constant MEM_MAP_BUFFER_DEFAULT : buffer_ping_pong_t :=
    ((inicio => x"38E00000", fim => x"38E13FF8", troca => x"38E0ffff"),
     (inicio => x"38E00000", fim => x"38E13FF8", troca => x"38E0ffff"));

  --constant MEM_MAP_BUFFER_SENSOR0 : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"000000", fim => "000" & x"013ff8", troca => "000" & x"00fff8"),
  --   (inicio => "000" & x"014000", fim => "000" & x"027ff8", troca => "000" & x"023ff8"));
  -- constant MEM_MAP_BUFFER_SENSOR0_RANDOM : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"000000", fim => "000" & x"013fff", troca => "000" & x"00ffff"),
  --    (inicio => "000" & x"014000", fim => "000" & x"027fff", troca => "000" & x"023fff"));
  -- --constant MEM_MAP_BUFFER_SENSOR1 : buffer_ping_pong_t :=
  -- --  ((inicio => "000" & x"028000", fim => "000" & x"03bff8", troca => "000" & x"037ff8"),
  -- --   (inicio => "000" & x"03c000", fim => "000" & x"04fff8", troca => "000" & x"04bff8"));
  -- constant MEM_MAP_BUFFER_SENSOR1_RANDOM : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"028000", fim => "000" & x"03bfff", troca => "000" & x"037fff"),
  --    (inicio => "000" & x"03c000", fim => "000" & x"04ffff", troca => "000" & x"04bfff"));
  
  -- constant MEM_MAP_BUFFER_FUSAO : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"050000", fim => "000" & x"063ff8", troca => "000" & x"05fff8"),
  --    (inicio => "000" & x"064000", fim => "000" & x"077ff8", troca => "000" & x"073ff8"));
  -- constant MEM_MAP_BUFFER_SWIR_NUC : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"078000", fim => "000" & x"08bff8", troca => "000" & x"087ff8"),
  --    (inicio => "000" & x"08c000", fim => "000" & x"09fff8", troca => "000" & x"09bff8"));
  
  -- constant MEM_MAP_BUFFER_LWIR_NUC : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"178000", fim => "000" & x"18bff8", troca => "000" & x"187ff8"),
  --    (inicio => "000" & x"18c000", fim => "000" & x"19fff8", troca => "000" & x"19bff8"));
  
  -- --eduardo: adicionando mapeamento de memória do swir
  -- --100Mhz
  -- --VERSAO PRA TESTE!
  -- constant MEM_MAP_BUFFER_SWIR_REF : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"000000", fim => "000" & x"027ff8", troca => "000" & x"023ff8"),
  --    (inicio => "000" & x"000000", fim => "000" & x"027ff8", troca => "000" & x"023ff8"));
  -- constant MEM_MAP_BUFFER_SWIR_RAW : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"028000", fim => "000" & x"04fff8", troca => "000" & x"04fff8"),
  --    (inicio => "000" & x"028000", fim => "000" & x"04fff8", troca => "000" & x"04fff8"));

  -- constant MEM_MAP_BUFFER_LWIR_REF : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"100000", fim => "000" & x"127ff8", troca => "000" & x"123ff8"),
  --    (inicio => "000" & x"100000", fim => "000" & x"127ff8", troca => "000" & x"123ff8"));
  -- constant MEM_MAP_BUFFER_LWIR_RAW : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"128000", fim => "000" & x"14fff8", troca => "000" & x"14fff8"),
  --    (inicio => "000" & x"128000", fim => "000" & x"14fff8", troca => "000" & x"14fff8" ));
  -- constant MEM_MAP_BUFFER_LWIR_RAW_50 : buffer_ping_pong_t :=
  --   ((inicio => "000" & x"128000", fim => "000" & x"8f7ff8", troca => "000" & x"8f7ff8"),
  --    (inicio => "000" & x"128000", fim => "000" & x"8f7ff8", troca => "000" & x"8f7ff8" ));
  
  --constant MEM_MAP_BUFFER_SENSOR0 : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"000000", fim => "000" & x"013ff8", troca => "000" & x"00A3B8"),
  --   (inicio => "000" & x"014000", fim => "000" & x"027ff8", troca => "000" & x"01E3B8"));
  --constant MEM_MAP_BUFFER_SENSOR_SWIR : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"028000", fim => "000" & x"04fff8", troca => "000" & x"04f9B8"),
  --   (inicio => "000" & x"028000", fim => "000" & x"04fff8", troca => "000" & x"04F9B8"));
  
  --constant MEM_MAP_BUFFER_VIDEO : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"050000", fim => "000" & x"063ff8", troca => "000" & x"05fff8"),
  --   (inicio => "000" & x"064000", fim => "000" & x"077ff8", troca => "000" & x"073ff8"));

  --constant MEM_MAP_BUFFER_HOMOG0 : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"078000", fim => "000" & x"08bff8", troca => "000" & x"087ff8"),
  --   (inicio => "000" & x"08c000", fim => "000" & x"09fff8", troca => "000" & x"09bff8"));
  --constant MEM_MAP_BUFFER_HOMOG1 : buffer_ping_pong_t :=
  --  ((inicio => "000" & x"0a0000", fim => "000" & x"0b3ff8", troca => "000" & x"0afff8"),
  --   (inicio => "000" & x"0b4000", fim => "000" & x"0c7ff8", troca => "000" & x"0c3ff8"));

  subtype buffer_id_t is std_logic_vector(0 downto 0);
  type    endr_gen_in_t is record
    rst_endr, prox_endr, buff_atual_in_en : std_logic;
    buff_atual_in                         : buffer_id_t;
  end record endr_gen_in_t;
  constant ENDR_GEN_IN_INIT : endr_gen_in_t := (
    rst_endr         => '0',
    prox_endr        => '0',
    buff_atual_in    => (others => '0'),
    buff_atual_in_en => '0'
    );

  type endr_gen_out_t is record
    buff_atual_out : buffer_id_t;
    endr_out       : endr_mem_t;
  end record endr_gen_out_t;
  constant ENDR_GEN_OUT_INIT : endr_gen_out_t := (
    buff_atual_out => (others => '0'),
    endr_out       => (others => '0')
    );

  component endr_gen is
    generic (
      BUFF_MAP : buffer_ping_pong_t
      );
    port (
      clk, rst_n   : in  std_logic;
      endr_gen_in  : in  endr_gen_in_t;
      endr_gen_out : out endr_gen_out_t
      );
  end component endr_gen;

  -----------------------------------------------------------------------------
  -- Tipos de dados e funcoes da homografia
  -----------------------------------------------------------------------------
  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_IR : integer := 15;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG_IR  : integer := 10;

  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_IR_ID : integer := 10;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG_IR_ID  : integer := 11;


  --CASO USE DIVISOR, DESCOMENTE CONFIGURACAO ABAIXO:
  --constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SR : integer := 8;
  --constant LARGURA_INT_PONTO_MATRIZ_HOMOG_SR  : integer := 19;

  --CASO USE SHIFTER, UTILIZE CONFIGURACAO ABAIXO:
  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SR : integer := 15;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG_SR  : integer := 11;

  --CASO USE SHIFTER, UTILIZE CONFIGURACAO ABAIXO:
  --constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SWIR : integer := 11;
  --constant LARGURA_INT_PONTO_MATRIZ_HOMOG_SWIR  : integer := 11;

   --CASO USE DIVISOR, UTILIZE CONFIGURACAO ABAIXO:
  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SWIR : integer := 15;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG_SWIR  : integer := 11;

  --CASO USE DIVISOR, UTILIZE CONFIGURACAO ABAIXO:
  constant LARGURA_FRAC_PONTO_MATRIZ_HOMOG_SWIR_GARCIA : integer := 20;
  constant LARGURA_INT_PONTO_MATRIZ_HOMOG_SWIR_GARCIA  : integer := 11;

  constant LARGURA_PONTO_MATRIZ : integer := 32;

  subtype ponto_matriz_homog_t is std_logic_vector(LARGURA_PONTO_MATRIZ-1 downto 0);
  type    linha_matriz_homog_t is array (0 to 2) of ponto_matriz_homog_t;
  type    matriz_homog_t is array (0 to 2) of linha_matriz_homog_t;

  constant DEF_LINHA_MATRIZ_HOMOG : linha_matriz_homog_t :=
    ((others => '0'), (others => '0'), (others => '0'));
  constant DEF_MATRIZ_HOMOG : matriz_homog_t :=
    (others => DEF_LINHA_MATRIZ_HOMOG);


  -- purpose: Preenche a matriz de homografia
  -- function func_preenche_matriz_homog(
  --   signal dados_in        : std_logic_vector(31 downto 0);
  --   i, j                   : unsigned(3 downto 0);
  --   signal matriz_homog_in : matriz_homog_t)
  --   return matriz_homog_t;

  -----------------------------------------------------------------------------
  -- Tipos de dados da fifo de dados
  -----------------------------------------------------------------------------  
  component fifo_dados is
    generic (
      PROFUNDIDADE_FIFO   : integer;
      LARGURA_FIFO        : integer;
      TAMANHO_BURST       : integer;
      N_BITS_PROFUNDIDADE : integer);
    port (
      rst_n       : in  std_logic;
      rd_clk      : in  std_logic;
      rd_req      : in  std_logic;
      rd_vazia    : out std_logic;
      rd_burst_en : out std_logic;
      data_q      : out std_logic_vector(LARGURA_FIFO-1 downto 0);
      wr_clk      : in  std_logic;
      wr_req      : in  std_logic;
      wr_cheia    : out std_logic;
      wr_burst_en : out std_logic;
      data_d      : in  std_logic_vector(LARGURA_FIFO-1 downto 0));
  end component fifo_dados;
  -----------------------------------------------------------------------------
  -- Tipos de dados do arbitro de memoria
  -----------------------------------------------------------------------------

  -- Tipos de dados para portas de escrita do arbitro
  type arb_porta_wr_in_t is record
    endr  : endr_mem_t;
    req   : std_logic;
    dados : word_mem_t;
  end record arb_porta_wr_in_t;
  constant ARB_PT_WR_IN_INIT : arb_porta_wr_in_t :=
    (endr  => (others => '0'),
     req   => '0',
     dados => (others => '0'));

  type arb_porta_wr_out_t is record
    prox_word : std_logic;
    prox_endr : std_logic;
  end record arb_porta_wr_out_t;
  constant ARB_PT_WR_OUT_INIT : arb_porta_wr_out_t :=
    (prox_word => '0',
     prox_endr => '0');

  -- Tipos de dados para portas de leitura do arbitro
  type arb_porta_rd_in_t is record
    endr : endr_mem_t;
    req  : std_logic;
  end record arb_porta_rd_in_t;
  constant ARB_PT_RD_IN_INIT : arb_porta_rd_in_t :=
    (endr => (others => '0'),
     req  => '0');

  type arb_porta_rd_out_t is record
    prox_endr_adiantado : std_logic;
    prox_endr           : std_logic;
    dados_validos       : std_logic;
    dados               : word_mem_t;
  end record arb_porta_rd_out_t;
  constant ARB_PT_RD_OUT_INIT : arb_porta_rd_out_t :=
    (prox_endr_adiantado => '0',
     prox_endr           => '0',
     dados_validos       => '0',
     dados               => (others => '0'));

  -- Tipo de dados de entrada do arbitro
  type arb_in_t is record
    sensor0    : arb_porta_wr_in_t;
    sensor1    : arb_porta_wr_in_t;
    fusao_out  : arb_porta_wr_in_t;
    homog_out  : arb_porta_wr_in_t;
    video0     : arb_porta_rd_in_t;
    video1     : arb_porta_rd_in_t;
    video2     : arb_porta_rd_in_t;
    fusao_in   : arb_porta_rd_in_t;
    homog_in   : arb_porta_rd_in_t;
    mem_data_q : word_mem_t;
  end record arb_in_t;
  constant ARB_IN_INIT : arb_in_t :=
    (sensor0    => ARB_PT_WR_IN_INIT,
     sensor1    => ARB_PT_WR_IN_INIT,
     fusao_out  => ARB_PT_WR_IN_INIT,
     homog_out  => ARB_PT_WR_IN_INIT,
     video0     => ARB_PT_RD_IN_INIT,
     video1     => ARB_PT_RD_IN_INIT,
     video2     => ARB_PT_RD_IN_INIT,
     fusao_in   => ARB_PT_RD_IN_INIT,
     homog_in   => ARB_PT_RD_IN_INIT,
     mem_data_q => (others => '0'));

  -- Tipo de dados de saida do arbitro
  type arb_out_t is record
    sensor0    : arb_porta_wr_out_t;
    sensor1    : arb_porta_wr_out_t;
    fusao_out  : arb_porta_wr_out_t;
    homog_out  : arb_porta_wr_out_t;
    video0     : arb_porta_rd_out_t;
    video1     : arb_porta_rd_out_t;
    video2     : arb_porta_rd_out_t;
    fusao_in   : arb_porta_rd_out_t;
    homog_in   : arb_porta_rd_out_t;
    mem_data_d : word_mem_t;
    mem_endr   : endr_mem_t;
    mem_we_n   : std_logic;
  end record arb_out_t;

  component arbitro_memoria is
    port (
      clk, rst_n : in  std_logic;
      arb_in     : in  arb_in_t;
      arb_out    : out arb_out_t);
  end component arbitro_memoria;
  -----------------------------------------------------------------------------
  -- OV9121
  -----------------------------------------------------------------------------
  constant OV_SCCB_N_PHASES_2 : std_logic := '0';
  constant OV_SCCB_N_PHASES_3 : std_logic := '1';

  constant OV_SCCB_RD_WR_READ  : std_logic := '0';
  constant OV_SCCB_RD_WR_WRITE : std_logic := '1';

  constant OV_SCCB_DEVICE_ADDR : std_logic_vector(6 downto 0) := "0110000";

  constant SYSTEM_CLK_F : integer := 150000000;
  constant OV_CLK_F     : integer := 12500000;

  type ov_ctr_sys_in_t is record
    get_frame, strt_config : std_logic;
    reg_config             : std_logic_vector(3 downto 0);
  end record ov_ctr_sys_in_t;
  type ov_ctr_sys_out_t is record
    valid_pixel, end_frame, end_config : std_logic;
    data_out                           : std_logic_vector(7 downto 0);
  end record ov_ctr_sys_out_t;

  type ov_ctr_in_t is record
    href, hsync, vsync, pclk : std_logic;
    sccb_d_in                : std_logic;
    data_in                  : std_logic_vector(9 downto 0);
    sys                      : ov_ctr_sys_in_t;
    addr_gen                 : endr_gen_in_t;
  end record ov_ctr_in_t;

  type ov_ctr_out_t is record
    sccb_c, sccb_d_out             : std_logic;
    fsin, vga, extstb, reset, frex : std_logic;
    sys                            : ov_ctr_sys_out_t;
    addr_gen                       : endr_gen_out_t;
  end record ov_ctr_out_t;

  component ov_controller is
    port (
      clk, rst_n : in  std_logic;
      ov_in      : in  ov_ctr_in_t;
      ov_out     : out ov_ctr_out_t);
  end component ov_controller;

  -----------------------------------------------------------------------------
  -- Vcomposite
  -----------------------------------------------------------------------------
  type vcomp_in_t is record
    addr_gen  : endr_gen_in_t;
    pixel     : word_mem_t;
    start_vid : std_logic;
    sw        : std_logic_vector(16 downto 0);
  end record vcomp_in_t;

  type vcomp_out_t is record
    addr_gen      : endr_gen_out_t;
    rd_req        : std_logic;
    compo_clk27   : std_logic;
    compo_hsync_n : std_logic;
    compo_vsync_n : std_logic;
    compo_blank_n : std_logic;
    compo_reset_n : std_logic;
    compo_p       : std_logic_vector(7 downto 0);
    compo_sclock  : std_logic;
    compo_sdata   : std_logic;
    eof           : std_logic;
  end record vcomp_out_t;

  component vcomposite is
    generic (
      BUFFER_ADDR      : buffer_ping_pong_t;
      MASTER_COMPONENT : boolean);
    port (
      clk        : in  std_logic;
      rst_n      : in  std_logic;
      mem_clk    : in  std_logic;
      clk_out    : out std_logic;
      vcomp_in   : in  vcomp_in_t;
      vcomp_out  : out vcomp_out_t);
  end component vcomposite;
  -----------------------------------------------------------------------------
  -- Tipos de dados do vga sequencer
  -----------------------------------------------------------------------------
  component vga_sequencer is
    port (
      vga_r, vga_g, vga_b          : out std_logic_vector(7 downto 0);
      vga_hs, vga_vs               : out std_logic;
      vga_blank_n, vga_sync_n      : out std_logic;
      sys_vid_en                   : out std_logic;
      sys_stop_sequencer           : in  std_logic;
      sys_r_in, sys_g_in, sys_b_in : in  std_logic_vector(7 downto 0);
      sys_vga_clk, rst_n           : in  std_logic);
  end component vga_sequencer;

  -----------------------------------------------------------------------------
  -- Shifter de imagem
  -----------------------------------------------------------------------------

  type fusao_in_t is record
    fixed_qt, float_qt                             : std_logic_vector(C_LARGURA_WORD_MEM-1 downto 0);
    tipo_fusao                                     : std_logic;
    threshold                                      : pixel_t;
    fixed_burst_en, float_burst_en, fusao_burst_en : std_logic;
  end record fusao_in_t;

  type fusao_out_t is record
    fixed_rd_req, float_rd_req, fusao_wr_req : std_logic;
    fusao_qt                                 : std_logic_vector(C_LARGURA_WORD_MEM-1 downto 0);
  end record fusao_out_t;

  component fusao is
    port (
      clk, rst_n : in  std_logic;
      fusao_in   : in  fusao_in_t;
      fusao_out  : out fusao_out_t);
  end component fusao;


  component img_shifter is
    generic (
      TAMANHO_LINHA       : integer := 320;
      N_BITS_ENDR_LINHA   : integer := 9;
      PROFUNDIDADE_FIFO   : integer := 512;
      N_BITS_PROFUNDIDADE : integer := 9;
      LARGURA_PIXEL       : integer := 16;
      TAMANHO_BURST       : integer := 16);
    port (
      rd_clk, wr_clk, rst_n : in  std_logic;
      x_offset              : in  std_logic_vector(N_BITS_ENDR_LINHA-1 downto 0);
      pixel_in              : in  std_logic_vector(LARGURA_PIXEL-1 downto 0);
      pixel_wr_req          : in  std_logic;
      pixel_wr_burst_en     : out std_logic;
      pixel_fila_cheia      : out std_logic;
      pixel_out             : out std_logic_vector(LARGURA_PIXEL-1 downto 0);
      pixel_rd_req          : in  std_logic;
      pixel_fila_vazia      : out std_logic;
      pixel_rd_burst_en     : out std_logic);
  end component img_shifter;

  -----------------------------------------------------------------------------
  -- Buffer histograma
  -----------------------------------------------------------------------------
  component buffer_histograma is
    generic (
      NUMERO_BINS       : integer;
      LARGURA_ADDR_BINS : integer;
      LARGURA_BINS      : integer);
    port (
      clk, rst_n : in  std_logic;
      bin_addr   : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
      incr_bin   : in  std_logic;
      zera_bin   : in  std_logic;
      value_out  : out std_logic_vector(LARGURA_BINS-1 downto 0));
  end component buffer_histograma;

  -------------------------------------------------------------------------------
  -- Calculo do mutual information
  -------------------------------------------------------------------------------

  --component calc_mi is
  --  generic (
  --    NUM_BINS                 : integer;
  --    NUM_BINS_BIT_WIDTH       : integer;
  --    NUM_IMG_SHIFTS           : integer;
  --    NUM_IMG_SHIFTS_BIT_WIDTH : integer;
  --    BIN_BIT_WIDTH            : integer;
  --    BIN_LOG_BIT_WIDTH        : integer;
  --    X_OFFSET_ADDR_WIDTH      : integer;
  --    X_OFFSET_START           : integer;
  --    X_OFFSET_END             : integer;
  --    X_OFFSET_WIDTH           : integer;
  --    X_OFFSET_STEP            : integer;
  --    LOG_OUT_FRAC_N_BITS      : integer);
  --  port (
  --    clk, rst_n               : in  std_logic;
  --    fixed_img_hist_addr      : out addr_1D_bus_t;
  --    fixed_img_hist_qt        : in  data_bus_t;
  --    float_img_hist_addr      : out addr_1D_bus_t;
  --    float_img_hist_qt        : in  data_bus_t;
  --    hist_2d_addr             : out addr_2D_bus_t;
  --    hist_2d_qt               : in  data_bus_t;
  --    hist_offset_addr         : out img_shift_t;
  --    const_hist_max_value_log : in  std_logic_vector(BIN_LOG_BIT_WIDTH+LOG_OUT_FRAC_N_BITS-1 downto 0);
  --    hist_busy                : in  std_logic;
  --    x_offset                 : out img_shift_t;
  --    end_of_frame             : out std_logic);
  --end component calc_mi;
  -----------------------------------------------------------------------------
  -- Calculo da entropia
  -----------------------------------------------------------------------------
  component cordic_rotation is
    port (
      clk, rst_n           : in  std_logic;
      angulo_in            : in  std_logic_vector(8 downto 0);
      valido_in            : in  std_logic;
      seno_out, coseno_out : out std_logic_vector(8 downto 0);
      valido_out           : out std_logic);
  end component cordic_rotation;

  component cordic_vectoring is
    port (
      clk, rst_n            : in  std_logic;
      x_in, y_in            : in  std_logic_vector(8 downto 0);
      valido_in             : in  std_logic;
      norma_out, angulo_out : out std_logic_vector(8 downto 0);
      valido_out            : out std_logic);
  end component cordic_vectoring;

  component filter_line_buffer is
    generic (
      NUMERO_COLUNAS           : integer;
      LARGURA_CONTADOR_COLUNAS : integer);
    port (
      clk, rst_n                   : in  std_logic;
      pixel_in                     : in  pixel_t;
      buffer_wr_sl                 : in  std_logic_vector(1 downto 0);
      pix_wr_en                    : in  std_logic;
      pixel_wr_addr, pixel_rd_addr : in  std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0);
      pixel_out_atual_linha        : out std_logic_vector(2*C_LARGURA_PIXEL-1 downto 0);
      pixel_out_ultima_linha       : out std_logic_vector(2*C_LARGURA_PIXEL-1 downto 0));
  end component filter_line_buffer;

  component sobel_cordic is
    generic (
      NUMERO_COLUNAS           : integer;
      LARGURA_CONTADOR_COLUNAS : integer;
      NUMERO_LINHAS            : integer;
      LARGURA_CONTADOR_LINHAS  : integer;
      NUMERO_SHIFTS            : integer;
      LARGURA_SHIFTS           : integer);
    port (
      clk, rst_n            : in  std_logic;
      pixel_in              : in  pixel_t;
      valido_in             : in  std_logic;
      norma_out, angulo_out : out std_logic_vector(8 downto 0);
      valido_out            : out std_logic);
  end component sobel_cordic;

  component ang_diff is
    port (
      clk, rst_n                                 : in  std_logic;
      img1_norma, img2_norma, img1_ang, img2_ang : in  std_logic_vector(8 downto 0);
      valido_in                                  : in  std_logic;
      diff_out                                   : out std_logic_vector(7 downto 0);
      ang_count                                  : out std_logic;
      valido_out                                 : out std_logic);
  end component ang_diff;

  component histograma_entropia is
    generic (
      NUMERO_BINS       : integer;
      LARGURA_ADDR_BINS : integer;
      LARGURA_BINS      : integer;
      NUMERO_SHIFTS     : integer);
    port (
      clk, rst_n         : in  std_logic;
      wr_bank_sl_one_hot : in  std_logic_vector(NUMERO_SHIFTS-1 downto 0);
      valor_in           : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
      ang_count_in       : in  std_logic;
      valido_in          : in  std_logic;
      clear_bin          : in  std_logic;
      rd_en              : in  std_logic;
      rd_addr            : in  std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
      rd_bin_out         : out std_logic_vector(LARGURA_BINS-1 downto 0);
      rd_total_out       : out std_logic_vector(LARGURA_BINS-1 downto 0);
      rd_bank_sl_one_hot : in  std_logic_vector(NUMERO_SHIFTS-1 downto 0));
  end component histograma_entropia;

  component calc_entropia is
    generic (
      NUMERO_BINS         : integer;
      LARGURA_ADDR_BINS   : integer;
      NUMERO_SHIFTS       : integer;
      LARGURA_SHIFTS      : integer;
      LARGURA_BINS        : integer;
      LARGURA_LOG_BIN     : integer;
      LOG_OUT_FRAC_N_BITS : integer);
    port (
      clk, rst_n         : in  std_logic;
      hist_bin_addr      : out std_logic_vector(LARGURA_ADDR_BINS-1 downto 0);
      hist_qt            : in  std_logic_vector(LARGURA_BINS-1 downto 0);
      hist_shift_one_hot : out std_logic_vector(NUMERO_SHIFTS-1 downto 0);
      hist_rd_en         : out std_logic;
      total_angulos      : in  std_logic_vector(LARGURA_BINS-1 downto 0);
      start_calc         : in  std_logic;
      shift_addr_out     : out std_logic_vector(LARGURA_SHIFTS-1 downto 0);
      end_of_frame       : out std_logic);
  end component calc_entropia;

  component entropia is
    generic (
      NUMERO_COLUNAS           : integer;
      LARGURA_CONTADOR_COLUNAS : integer;
      NUMERO_LINHAS            : integer;
      LARGURA_CONTADOR_LINHAS  : integer;
      LARGURA_SHIFTS           : integer;
      LARGURA_PASSO            : integer;
      LARGURA_BINS             : integer;
      LARGURA_ADDR_BINS        : integer);
    port (
      clk, rst_n                               : in  std_logic;
      start_frame                              : in  std_logic;
      end_frame                                : out std_logic;
      fxd_pix_in, flt_pix_in                   : in  pixel_t;
      fxd_pix_rd_req, flt_pix_rd_req           : out std_logic;
      fxd_pix_rd_burst_en, flt_pix_rd_burst_en : in  std_logic;
      fxd_pix_out, flt_pix_out                 : out pixel_t;
      fxd_pix_wr_req, flt_pix_wr_req           : out std_logic;
      fxd_pix_wr_burst_en, flt_pix_wr_burst_en : in  std_logic;
      offset                                   : out std_logic_vector(LARGURA_CONTADOR_COLUNAS-1 downto 0));
  end component entropia;

  -----------------------------------------------------------------------------
  -- Tipos de dados do jtag wrapper
  -----------------------------------------------------------------------------
  constant JTAG_INST_LENGTH     : integer := 8;
  constant JTAG_DATA_LENGTH     : integer := 256;
  constant JTAG_MEM_WORD_LENGTH : integer := 16;


  constant JTAG_REG_LENGTH          : integer := 16;
  constant JTAG_REG_MEM_ADDR0       : integer := 0;
  constant JTAG_REG_MEM_ADDR1       : integer := 1;
  constant JTAG_REG_MEM_OP_SIZE0    : integer := 2;
  constant JTAG_REG_MEM_OP_SIZE1    : integer := 3;
  constant JTAG_REG_CONFIG          : integer := 4;
  constant JTAG_REG_MATRIZ_HOMOG_L  : integer := 5;
  constant JTAG_REG_MATRIZ_HOMOG_H  : integer := 6;
  constant JTAG_REG_OFFSET          : integer := 7;
  constant JTAG_REG_ALPHA           : integer := 8;
  constant JTAG_REG_THRESHOLD       : integer := 9;
  constant JTAG_REG_PALLETE         : integer := 10;
  constant JTAG_REG_JTAG_TIPO_FUSAO : integer := 11;
  constant JTAG_REG_BRILHO_OFFSET   : integer := 12;
  constant JTAG_REG_SWIR_REGISTERS   : integer := 13;


  
  subtype jtag_reg_t is std_logic_vector(JTAG_REG_LENGTH-1 downto 0);
  
  function jtag_get_reg (
    signal jtag_data_in : std_logic_vector(JTAG_DATA_LENGTH-1 downto 0);
    reg_num             : integer)
    return jtag_reg_t;



  function acha_bit_mais_alto (
    constant LARGURA_SAIDA : in integer;
    valor_in               :    unsigned)
    return unsigned;

  
  function shifta_fixed_mantissa (
    constant LARGURA_SAIDA : integer;
    valor_in               : unsigned;
    shift_count            : unsigned)
    return unsigned;

  function shifta_float_mantissa (
    constant LARGURA_SAIDA_INT  : integer;
    constant LARGURA_SAIDA_FRAC : integer;
    valor_in                    : unsigned;
    shift_count                 : signed)
    return unsigned;

end package uteis;

package body uteis is
  -- function func_preenche_matriz_homog(
  --   signal dados_in        : std_logic_vector(31 downto 0);
  --   i, j                   : unsigned(2 downto 0);
  --   signal matriz_homog_in : matriz_homog_t)
  --   return matriz_homog_t is
  --   variable matriz_aux : matriz_homog_t;
  -- begin  -- function preenche_matriz_homog
  --   matriz_aux := matriz_homog_in;
  --   matriz_aux(to_integer(i))(to_integer(j)) := dados_in(LARGURA_PONTO_MATRIZ-1 downto
  --                                                        0);
  --   return matriz_aux;
  -- end function func_preenche_matriz_homog;


  function jtag_get_reg (
    signal jtag_data_in : std_logic_vector(JTAG_DATA_LENGTH-1 downto 0);
    reg_num             : integer)
    return jtag_reg_t is
  begin
    return jtag_data_in(JTAG_REG_LENGTH*(reg_num+1)-1 downto JTAG_REG_LENGTH*reg_num);
  end function jtag_get_reg;



  -----------------------------------------------------------------------------
  -- Operacoes de ponto flutuante
  -----------------------------------------------------------------------------

  -- purpose: Acha o bit mais alto do valor da entrada e retorna a posicao dele
  function acha_bit_mais_alto (
    constant LARGURA_SAIDA : in integer;
    valor_in               :    unsigned)
    return unsigned is
    variable pos_bit_alto : integer := 0;
  begin  -- function acha_bit_mais_alto
    pos_bit_alto := 0;
    for i in 0 to valor_in'high-1 loop
      if '1' = valor_in(i) then
        pos_bit_alto := i;
      end if;
    end loop;  -- i in 
    return to_unsigned(pos_bit_alto, LARGURA_SAIDA);
  end function acha_bit_mais_alto;

  -- purpose: Shifta a entrada por shift_count bits para a direita,
  -- Retorna os valores nos bits fracionarios da entrada
  function shifta_fixed_mantissa (
    constant LARGURA_SAIDA : integer;
    valor_in               : unsigned;
    shift_count            : unsigned)
    return unsigned is
    variable shift_count_int : integer;
    variable shifter_aux     : unsigned(valor_in'length+LARGURA_SAIDA-1 downto 0);
  begin  -- function shifta_fixed_mantissa
    shifter_aux(shifter_aux'high downto LARGURA_SAIDA) := valor_in;
    shifter_aux(LARGURA_SAIDA-1 downto 0)              := (others => '0');
    shift_count_int                                    := to_integer(shift_count);
    shifter_aux                                        := shift_right(shifter_aux, shift_count_int);

    return shifter_aux(LARGURA_SAIDA-1 downto 0);
  end function shifta_fixed_mantissa;

  -- purpose: Shifta a entrada por shift_count bits para a direita,
  -- Retorna os valores nos bits fracionarios da entrada
  function shifta_float_mantissa (
    constant LARGURA_SAIDA_INT  : integer;
    constant LARGURA_SAIDA_FRAC : integer;
    valor_in                    : unsigned;
    shift_count                 : signed)
    return unsigned is
    variable shift_count_int : integer;
    variable shifter_aux     : unsigned(LARGURA_SAIDA_FRAC + LARGURA_SAIDA_INT + valor_in'length - 1 downto 0);
  begin  -- function shifta_float_mantissa
    shifter_aux(valor_in'length - 1 downto 0)            := valor_in;
    shifter_aux(shifter_aux'high downto valor_in'length) := (others => '0');

    shifter_aux     := shift_left(shifter_aux, LARGURA_SAIDA_FRAC);
    shift_count_int := to_integer(shift_count);
    if shift_count_int > 0 then
      shifter_aux := shift_left(shifter_aux, shift_count_int);
    elsif shift_count_int < 0 then
      shifter_aux := shift_right(shifter_aux, -shift_count_int);
    end if;


    return shifter_aux(shifter_aux'high downto valor_in'length);
  end function shifta_float_mantissa;
  
end package body uteis;
