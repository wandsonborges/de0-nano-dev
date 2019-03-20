-------------------------------------------------------------------------------
-- Title      : fusao
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fusao.vhd
-- Author     :   <mdrumond@FOURIER>
-- Company    : 
-- Created    : 2013-10-17
-- Last update: 2019-03-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o algoritmo de fusao escolhido
--              Por equanto faz media aritmetica dos pixels
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author             Description
-- 2013-10-17  1.0      mdrumond           Created
-- 2014-09-25  1.1      rodrigo.oliveira   Update -> Novos tipos de fusao
-- 2015-01-20  1.2      rodrigo.oliveira   Update -> Equalizacao histograma do termal!
-- 2017-10-24  1.3      fernando.daldegan  Update -> Incluido controle pelo menu
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.uteis.all;

LIBRARY altera_mf;
USE altera_mf.all;

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
entity fusao is  
  port (
    rst_n                : in std_logic;
    clk                  : in std_logic;
    pixel_fxd_fusao_in   : in pixel_t;
    pixel_flt_fusao_in   : in pixel_t;
    pixel_fusao_valid_in : in std_logic;
    brilho_offset        : in std_logic_vector(7 downto 0);
    tipo_fusao           : in std_logic_vector(1 downto 0);
    alpha                : in std_logic_vector(7 downto 0);
    pallete_select       : in std_logic_vector(1 downto 0);
    threshold            : in pixel_t;
    --jtag_tipo_fusao      : in std_logic_vector(1 downto 0);
    
    clear                : in std_logic;

    current_alpha     : out std_logic_vector(7 downto 0);
    current_threshold : out std_logic_vector(7 downto 0);
    
    fusao_out_wr_req : out std_logic;
    pixel_fusao_out  : out std_logic_vector(C_LARGURA_WORD_MEM-1 downto 0)
    );
end entity fusao;

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
architecture fpga of fusao is
  --
  type flop_init_t is record
    fixed_qt    : std_logic_vector(7 downto 0);
    float_qt    : std_logic_vector(7 downto 0);
    --alpha       : unsigned(7 downto 0);
    pixel_impar : std_logic;
    valido      : std_logic;
  end record flop_init_t;
  constant DEF_FLOP_INIT : flop_init_t :=
    (fixed_qt    => (others => '0'),
     float_qt    => (others => '0'),
     --alpha       => (others => '0'),
     pixel_impar => '0',
     valido      => '0'
     );
  signal flop_init : flop_init_t := DEF_FLOP_INIT;

  -- fusao baseada em hsi
  type flop_ycrcb_lut_t is record
    pixel_impar : std_logic;
    crcb        : std_logic_vector(15 downto 0);
    y           : std_logic_vector(7 downto 0);
    valido      : std_logic;
  end record flop_ycrcb_lut_t;
  constant DEF_FLOP_YCRCB_LUT : flop_ycrcb_lut_t := (
    crcb        => (others => '0'),
    y           => (others => '0'),
    pixel_impar => '0',
    valido      => '0'
    );
  signal flop_ycrcb_lut : flop_ycrcb_lut_t := DEF_FLOP_YCRCB_LUT;

  --
  type flop_fusao_hsi_t is record
    ycrcb_out   : std_logic_vector(15 downto 0);
    pixel_impar : std_logic;
    valido      : std_logic;
  end record flop_fusao_hsi_t;
  constant DEF_FLOP_FUSAO_HSI : flop_fusao_hsi_t := (
    ycrcb_out   => (others => '0'),
    pixel_impar => '0',
    valido      => '0'
    );
  signal flop_fusao_hsi : flop_fusao_hsi_t := DEF_FLOP_FUSAO_HSI;

  --
  type flop_espera_hsi_t is record
    ycrcb_out : std_logic_vector(15 downto 0);
    valido    : std_logic;
  end record flop_espera_hsi_t;
  constant DEF_FLOP_ESPERA_HSI : flop_espera_hsi_t := (
    ycrcb_out => (others => '0'),
    valido    => '0'
    );

  --
  constant NUM_CICLOS_ESPERA_HSI : integer            := 5;
  type array_espera_hsi_t is array (0 to NUM_CICLOS_ESPERA_HSI-1) of flop_espera_hsi_t;
  constant DEF_ARRAY_ESPERA_HSI  : array_espera_hsi_t := (others => DEF_FLOP_ESPERA_HSI);
  signal array_espera_hsi        : array_espera_hsi_t := DEF_ARRAY_ESPERA_HSI;

  ------------------------------------------------------------------------------
  -- estrutura de configuracao da fusao
  ------------------------------------------------------------------------------
  type fusao_config_t is record
    threshold : std_logic_vector(7 downto 0);
    alpha : unsigned(7 downto 0);
    --brilho_offset : signed(7 downto 0);
    fusao_out_wr_req : std_logic;
    pixel_fusao_out : std_logic_vector(C_LARGURA_WORD_MEM-1 downto 0);
  end record fusao_config_t;

  ------------------------------------------------------------------------------
  -- 
  ------------------------------------------------------------------------------
  signal ycrcb_lut_addr : std_logic_vector(11 downto 0);
  signal ycrcb_lut_out  : std_logic_vector(23 downto 0);

  signal rgb_ycrcb_out        : std_logic_vector(15 downto 0);
  signal rgb_ycrcb_valido_out : std_logic;

  signal pixel_flt_fusao_in_ajuste : pixel_t;
  signal pixel_flt_fusao_in_scaled : pixel_t;
  signal clear_flop1               : std_logic := '0';
  signal clear_flop2               : std_logic := '0';

  ------------------------------------------------------------------------------
  -- fusao baseada em media rgb
  ------------------------------------------------------------------------------ 
  type flop_rgb_t is record
    fixed_r, fixed_g, fixed_b : std_logic_vector(7 downto 0);
    float_r, float_g, float_b : std_logic_vector(7 downto 0);
    valido                    : std_logic;
  end record flop_rgb_t;
  constant DEF_FLOP_RGB : flop_rgb_t := (
    fixed_r => (others => '0'),
    fixed_g => (others => '0'),
    fixed_b => (others => '0'),
    float_r => (others => '0'),
    float_g => (others => '0'),
    float_b => (others => '0'),
    valido  => '0'
    );
  signal flop_rgb : flop_rgb_t := DEF_FLOP_RGB;

  type flop_fusao_rgb_t is record
    fusao_r, fusao_g, fusao_b : std_logic_vector(7 downto 0);
    valido                    : std_logic;
  end record flop_fusao_rgb_t;
  constant DEF_FLOP_FUSAO_RGB : flop_fusao_rgb_t := (
    fusao_r => (others => '0'),
    fusao_g => (others => '0'),
    fusao_b => (others => '0'),
    valido  => '0'
    );
  signal flop_fusao_rgb : flop_fusao_rgb_t := DEF_FLOP_FUSAO_RGB;

  type flop_fusao_rgb_ycrcb_t is record
    fusao_out : std_logic_vector(C_LARGURA_WORD_MEM-1 downto 0);
    valido    : std_logic;
  end record flop_fusao_rgb_ycrcb_t;
  constant DEF_FLOP_FUSAO_RGB_YCRCB : flop_fusao_rgb_ycrcb_t := (
    fusao_out => (others => '0'),
    valido    => '0'
    );
  signal flop_fusao_rgb_ycrcb : flop_fusao_rgb_ycrcb_t := DEF_FLOP_FUSAO_RGB_YCRCB;

  signal fusao_config : fusao_config_t;

  signal rgb_lut_addr : std_logic_vector( 7 downto 0);
  signal rgb_lut_out  : std_logic_vector(23 downto 0);
  signal rgb_lut0_out : std_logic_vector(23 downto 0);
  signal rgb_lut1_out : std_logic_vector(23 downto 0);
  signal rgb_lut2_out : std_logic_vector(23 downto 0);
  
  signal alpha_lut : std_logic_vector(7 downto 0);

  signal tipo_fusao_i     : std_logic_vector(    tipo_fusao'length-1 downto 0);
  signal alpha_i          : std_logic_vector(         alpha'length-1 downto 0);
  signal pallete_select_i : std_logic_vector(pallete_select'length-1 downto 0);
  signal threshold_i      : std_logic_vector(     threshold'length-1 downto 0);
  
  signal alpha_offset_jtag : std_logic_vector(7 downto 0) := x"00";
  signal s_open : std_logic_vector(0 downto 0) := "0";

  ------------------------------------------------------------------------------

begin  -- architecture fpga

  ------------------------------------------------------------------------------
  -- Sincronizacao dos sinais do Menu
  ------------------------------------------------------------------------------
  dFfVectorSynchronizer_1 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => tipo_fusao'length
      )
    port map (
      nReset => rst_n,
      clock  => clk,
      input  => tipo_fusao,
      output => tipo_fusao_i
      );

  dFfVectorSynchronizer_2 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => alpha'length
      )
    port map (
      nReset => rst_n,
      clock  => clk,
      input  => alpha,
      output => alpha_i
      );

  dFfVectorSynchronizer_3 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => pallete_select'length
      )
    port map (
      nReset => rst_n,
      clock  => clk,
      input  => pallete_select,
      output => pallete_select_i
      );

  dFfVectorSynchronizer_4 : entity work.dFfVectorSynchronizer
    generic map (
      SYNCHRONIZATION_STAGES => 2,
      REGISTER_WIDTH         => threshold'length
      )
    port map (
      nReset => rst_n,
      clock  => clk,
      input  => threshold,
      output => threshold_i
      );

  ------------------------------------------------------------------------------
  -- purpose: Implementa a fusao
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
    variable resultado_soma_r : unsigned(15 downto 0) := (others => '0');
    variable resultado_soma_g : unsigned(15 downto 0) := (others => '0');
    variable resultado_soma_b : unsigned(15 downto 0) := (others => '0');

  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_init        <= DEF_FLOP_INIT;
      flop_ycrcb_lut   <= DEF_FLOP_YCRCB_LUT;
      flop_fusao_hsi   <= DEF_FLOP_FUSAO_HSI;
      array_espera_hsi <= DEF_ARRAY_ESPERA_HSI;

      flop_rgb             <= DEF_FLOP_RGB;
      flop_fusao_rgb       <= DEF_FLOP_FUSAO_RGB;
      flop_fusao_rgb_ycrcb <= DEF_FLOP_FUSAO_RGB_YCRCB;
      clear_flop1          <= '0';
      clear_flop2          <= '0';

    elsif clk'event and clk = '1' then  -- rising clock edge

      clear_flop1 <= clear;
      clear_flop2 <= clear_flop1;

      flop_init.valido <= pixel_fusao_valid_in;
      
      if '1' = flop_init.valido then
        flop_init.pixel_impar <= not flop_init.pixel_impar;
      else
        flop_init.pixel_impar <= flop_init.pixel_impar;
      end if;

      if unsigned(pixel_flt_fusao_in_ajuste) > unsigned(fusao_config.threshold) then
        flop_init.float_qt <= pixel_flt_fusao_in_ajuste;
        --flop_init.alpha <= unsigned(alpha_i);
      else
        flop_init.float_qt <= (others => '0');
        --flop_init.alpha <= (others => '1');
      end if;
      flop_init.fixed_qt <= pixel_fxd_fusao_in;
      --flop_init.alpha <= unsigned(alpha_lut);

      -- pipeline que calcula a fusao baseado em hsi
      flop_ycrcb_lut.valido      <= flop_init.valido;
      flop_ycrcb_lut.pixel_impar <= flop_init.pixel_impar;
      flop_ycrcb_lut.crcb        <= ycrcb_lut_out(23 downto 8);
      flop_ycrcb_lut.y           <= ycrcb_lut_out(7 downto 0);

      flop_fusao_hsi.valido                <= flop_ycrcb_lut.valido;
      flop_fusao_hsi.pixel_impar           <= flop_ycrcb_lut.pixel_impar;
      flop_fusao_hsi.ycrcb_out(7 downto 0) <= flop_ycrcb_lut.y;
      -- manda o cb primeiro e o cr depois
      if '1' = flop_fusao_hsi.valido and '0' = flop_fusao_hsi.pixel_impar then
        flop_fusao_hsi.ycrcb_out(15 downto 8) <= flop_ycrcb_lut.crcb(15 downto 8);
      elsif '1' = flop_fusao_hsi.valido then
        flop_fusao_hsi.ycrcb_out(15 downto 8) <= flop_ycrcb_lut.crcb(7 downto 0);
      end if;

      array_espera_hsi(0).ycrcb_out <= flop_fusao_hsi.ycrcb_out;
      array_espera_hsi(0).valido    <= flop_fusao_hsi.valido;
      for i in 1 to NUM_CICLOS_ESPERA_HSI-1 loop
        array_espera_hsi(i) <= array_espera_hsi(i-1);
      end loop;  -- i

      -- pipeline que calcula a fusao baseado em media
      flop_rgb.valido  <= flop_init.valido;
      flop_rgb.fixed_r <= flop_init.fixed_qt;
      flop_rgb.fixed_g <= flop_init.fixed_qt;
      flop_rgb.fixed_b <= flop_init.fixed_qt;

      if unsigned(flop_init.float_qt) > unsigned(threshold_i) then
        flop_rgb.float_r <= rgb_lut_out(7 downto 0);
        flop_rgb.float_g <= rgb_lut_out(15 downto 8);
        flop_rgb.float_b <= rgb_lut_out(23 downto 16);
      else
        flop_rgb.float_r <= (others => '0');
        flop_rgb.float_g <= (others => '0');
        flop_rgb.float_b <= (others => '0');
      end if;

      resultado_soma_r := unsigned(flop_rgb.fixed_r) * fusao_config.alpha +
                          unsigned(flop_rgb.float_r) * (255-fusao_config.alpha);
      resultado_soma_g := unsigned(flop_rgb.fixed_g) * fusao_config.alpha +
                          unsigned(flop_rgb.float_g) * (255-fusao_config.alpha);
      resultado_soma_b := unsigned(flop_rgb.fixed_b) * fusao_config.alpha +
                          unsigned(flop_rgb.float_b) * (255-fusao_config.alpha);

      flop_fusao_rgb.fusao_r <= std_logic_vector(resultado_soma_r(15 downto 8));
      flop_fusao_rgb.fusao_g <= std_logic_vector(resultado_soma_g(15 downto 8));
      flop_fusao_rgb.fusao_b <= std_logic_vector(resultado_soma_b(15 downto 8));
      flop_fusao_rgb.valido  <= flop_rgb.valido;

      flop_fusao_rgb_ycrcb.fusao_out <= rgb_ycrcb_out;
      flop_fusao_rgb_ycrcb.valido    <= rgb_ycrcb_valido_out;

      -- saida da fusao
      if "00" = tipo_fusao_i then
        fusao_out_wr_req <= array_espera_hsi(NUM_CICLOS_ESPERA_HSI-1).valido;
        pixel_fusao_out  <= array_espera_hsi(NUM_CICLOS_ESPERA_HSI-1).ycrcb_out;
      else
        fusao_out_wr_req <= fusao_config.fusao_out_wr_req;
        pixel_fusao_out  <= fusao_config.pixel_fusao_out;
      end if;
      
    end if;

  end process clk_proc;
  
  ------------------------------------------------------------------------------
  -- purpose: ESCOLHE PALLETE
  -- type   : combinational
  -- inputs : pallete_select
  -- outputs: rgb_lut_out
  escolhe_pallete: process (pallete_select_i) is
  begin  -- process escolhe_pallete
    case pallete_select_i is
      when "00"   => rgb_lut_out <= rgb_lut0_out;
      when "01"   => rgb_lut_out <= rgb_lut1_out;
      when others => rgb_lut_out <= rgb_lut2_out;
    end case;
  end process escolhe_pallete;

  ------------------------------------------------------------------------------
  -- purpose:
  -- type   :
  -- inputs :
  -- outputs:
  escolhe_fusao: process (clk, rst_n) is
  begin  -- process escolhe_fusao
    if rst_n = '0' then
      fusao_config.threshold <= (others => '0');
      fusao_config.alpha <= (others => '0');
      fusao_config.fusao_out_wr_req <= flop_fusao_rgb_ycrcb.valido;
      fusao_config.pixel_fusao_out <= flop_fusao_rgb_ycrcb.fusao_out;

    elsif clk'event and clk = '1' then
      current_threshold <= threshold_i;
      
      if (tipo_fusao_i = "00") then
        current_alpha <= alpha_i;
        fusao_config.threshold <= threshold_i;
        fusao_config.alpha <= unsigned(alpha_i);
        fusao_config.fusao_out_wr_req <= array_espera_hsi(NUM_CICLOS_ESPERA_HSI-1).valido;
        fusao_config.pixel_fusao_out  <= array_espera_hsi(NUM_CICLOS_ESPERA_HSI-1).ycrcb_out;
        
      elsif (tipo_fusao_i = "01") then
        --alpha_lut <= alpha_lut - alpha_offset_jtag; --x"30";
        fusao_config.threshold <= threshold_i;
        fusao_config.alpha <= unsigned(alpha_lut - alpha_offset_jtag);
        fusao_config.fusao_out_wr_req <= flop_fusao_rgb_ycrcb.valido;
        fusao_config.pixel_fusao_out <= flop_fusao_rgb_ycrcb.fusao_out;

      elsif (tipo_fusao_i = "10") then
        current_alpha <= (others => '1');
        fusao_config.threshold <= threshold_i;
        if unsigned(pixel_flt_fusao_in_ajuste) > unsigned(fusao_config.threshold) then
          fusao_config.alpha <= (others => '0');
        else
          fusao_config.alpha <= (others => '1');
        end if;
        fusao_config.fusao_out_wr_req <= flop_fusao_rgb_ycrcb.valido;
        fusao_config.pixel_fusao_out <= flop_fusao_rgb_ycrcb.fusao_out;

      else -- tipo_fusao_i = "11"
        current_alpha <= alpha_i;
        fusao_config.threshold <= threshold_i;
        if unsigned(pixel_flt_fusao_in_ajuste) > unsigned(fusao_config.threshold) then
          fusao_config.alpha <= unsigned(alpha_i);
        else
          fusao_config.alpha <= (others => '1');
        end if;
        fusao_config.fusao_out_wr_req <= flop_fusao_rgb_ycrcb.valido;
        fusao_config.pixel_fusao_out <= flop_fusao_rgb_ycrcb.fusao_out;
      end if;
    end if;
    
  end process escolhe_fusao;

  ------------------------------------------------------------------------------
  ycrcb_lut_addr <= std_logic_vector(flop_init.fixed_qt(7 downto 2)) &
                    std_logic_vector(flop_init.float_qt(7 downto 2));

  --Comentado por falta de espaço
  -- ROM_Pallete_hsi_1 : entity work.ROM_Pallete_hsi
  --   port map (
  --     address => ycrcb_lut_addr,
  --     clock   => clk,
  --     q       => ycrcb_lut_out
  --     );
  --------------------------------------
  rgb_lut_addr <= flop_init.float_qt;

  ROM_Pallete_rgb_hot : entity work.ROM_Pallete_rgb_quente
    port map (
      address => rgb_lut_addr,
      clock   => clk,
      q       => rgb_lut0_out
      );

  ROM_Pallete_rgb_cold : entity work.ROM_Pallete_rgb_fria
    port map (
      address => rgb_lut_addr,
      clock   => clk,
      q       => rgb_lut1_out
      );

  ROM_Pallete_rgb_std : entity work.ROM_Pallete_rgb_escalada --ROM_Pallete_rgb_standard
    port map (
      address => rgb_lut_addr,
      clock   => clk,
      q       => rgb_lut2_out
      );

  ROM_alpha_rgb : entity work.ROM_alpha_rgb
    port map (
      address => rgb_lut_addr,
      clock   => clk,
      q       => alpha_lut
      );

  rgb_ycrcb_1 : entity work.rgb_ycrcb
    port map (
      r_in       => flop_fusao_rgb.fusao_r,
      g_in       => flop_fusao_rgb.fusao_g,
      b_in       => flop_fusao_rgb.fusao_b,
      valido_in  => flop_fusao_rgb.valido,
      ycrcb      => rgb_ycrcb_out,
      valido_out => rgb_ycrcb_valido_out,
      clk        => clk,
      rst_n      => rst_n
      );

  adder_sat_1: entity work.adder_sat
    generic map (
      nbits     => 8,
      valor_max => 255,
      valor_min => 0
      )
    port map (
      rst_n  => rst_n,
      n1     => pixel_flt_fusao_in,
      n2     => brilho_offset,
      result => pixel_flt_fusao_in_ajuste
      );

  -- -- daldegan: ativa LUT para controle do offset
  altsource_probe_component_alpha_offset : altera_mf.altera_mf_components.altsource_probe
    GENERIC MAP (
      enable_metastability => "YES",
      instance_id => "aOfs",
      probe_width => 1,
      sld_auto_instance_index => "YES",
      sld_instance_index => 0,
      source_initial_value => x"00",
      source_width => 8,
      lpm_type => "altsource_probe"
      )
    PORT MAP (
      probe => s_open,
      source_clk => clk,
      source_ena => '1',
      source => alpha_offset_jtag
      );
  
end architecture fpga;
