-------------------------------------------------------------------------------
-- Title      : rgb_ycrcb
-- Project    : 
-------------------------------------------------------------------------------
-- File       : rgb_ycrcb.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-10-31
-- Last update: 2014-02-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: converts rgb to ycrcb
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-10-31  1.0      mdrumond	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uteis.all;


entity rgb_ycrcb is
  
  port (
    r_in, g_in, b_in : in  std_logic_vector(7 downto 0);
    valido_in        : in  std_logic;
    ycrcb            : out std_logic_vector(15 downto 0);
    valido_out       : out std_logic;
    clk, rst_n       : in  std_logic);

end entity rgb_ycrcb;
architecture fpga of rgb_ycrcb is
  constant CALC_WORD_WIDTH : integer := 8;
  subtype calc_word_t is unsigned(CALC_WORD_WIDTH-1 downto 0);
  subtype calc_word_signed_t is signed(CALC_WORD_WIDTH downto 0);

  type flop_color_rgb_t is record
    r, g, b : calc_word_t;
    valido  : std_logic;
  end record flop_color_rgb_t;
  constant DEF_FLOP_COLOR_RGB : flop_color_rgb_t := (
    r      => (others => '0'),
    g      => (others => '0'),
    b      => (others => '0'),
    valido => '0');
  signal flop_rgb : flop_color_rgb_t := DEF_FLOP_COLOR_RGB;

  type fator_conversao_t is array (0 to 2) of calc_word_signed_t;
  -- fatores de conversao para r, g e b, nessa ordem
  constant fator_mult_y : fator_conversao_t := (
    '0' & x"41", '0' & x"81", '0' & x"19");  -- 65 129 25
  constant fator_mult_cb : fator_conversao_t := (
    '1' & x"da", '1' & x"b6", '0' & x"70");  --  -38 -74 112
  constant fator_mult_cr : fator_conversao_t := (
    '0' & x"70", '1' & x"a2", '1' & x"EE");  --   112 -94 -18

  type flop_conversao_mult_t is record
    ypar1, ypar2, ypar3    : calc_word_signed_t;
    crpar1, crpar2, crpar3 : calc_word_signed_t;
    cbpar1, cbpar2, cbpar3 : calc_word_signed_t;
    valido                 : std_logic;
  end record flop_conversao_mult_t;
  constant DEF_FLOP_CONVERSAO_MULT : flop_conversao_mult_t := (
    ypar1  => (others => '0'),
    ypar2  => (others => '0'),
    ypar3  => (others => '0'),
    crpar1 => (others => '0'),
    crpar2 => (others => '0'),
    crpar3 => (others => '0'),
    cbpar1 => (others => '0'),
    cbpar2 => (others => '0'),
    cbpar3 => (others => '0'),
    valido => '0');

  signal flop_mult_conv : flop_conversao_mult_t :=
    DEF_FLOP_CONVERSAO_MULT;

  subtype conversao_mult_aux_t is signed(2+2*CALC_WORD_WIDTH-1 downto 0);
  type conversao_mult_aux_group_t is record
    ypar1, ypar2, ypar3    : conversao_mult_aux_t;
    crpar1, crpar2, crpar3 : conversao_mult_aux_t;
    cbpar1, cbpar2, cbpar3 : conversao_mult_aux_t;
  end record conversao_mult_aux_group_t;
  constant MULT_SIGNAL_BIT : integer := 2*CALC_WORD_WIDTH;
  constant MULT_LSB_BIT    : integer := CALC_WORD_WIDTH;

  type flop_conversao_res_t is record
    y, cr, cb : calc_word_t;
    valido    : std_logic;
  end record flop_conversao_res_t;
  constant DEF_FLOP_CONVERSAO_RES : flop_conversao_res_t := (
    y      => (others => '0'),
    cr     => (others => '0'),
    cb     => (others => '0'),
    valido => '0');
  signal flop_conv_res : flop_conversao_res_t := DEF_FLOP_CONVERSAO_RES;

  type serialization_state_t is (SERIAL_ST_EVEN, SERIAL_ST_ODD);
  type flop_serialization_t is record
    serialization_state : serialization_state_t;
    valid               : std_logic;
    cr                  : std_logic_vector(7 downto 0);
    ycbcr_422           : std_logic_vector(15 downto 0);
  end record flop_serialization_t;
  constant DEF_FLOP_SERIALIZATION : flop_serialization_t := (
    serialization_state => SERIAL_ST_EVEN,
    valid               => '0',
    cr                  => (others => '0'),
    ycbcr_422           => (others => '0'));
  signal flop_serial : flop_serialization_t := DEF_FLOP_SERIALIZATION;

begin  -- architecture fpga


-- purpose: Implementa a fusao
-- type   : sequential
-- inputs : clk, rst_n
-- outputs: 
  clk_proc : process (clk, rst_n) is
    variable conv_mult_aux         : conversao_mult_aux_group_t;
    variable y_aux, cr_aux, cb_aux : calc_word_signed_t;
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_rgb       <= DEF_FLOP_COLOR_RGB;
      flop_mult_conv <= DEF_FLOP_CONVERSAO_MULT;
      flop_conv_res  <= DEF_FLOP_CONVERSAO_RES;
      flop_serial    <= DEF_FLOP_SERIALIZATION;
    elsif clk'event and clk = '1' then  -- rising clock edge

      -- estagio 1 : grayscale para rgb
      flop_rgb.r <= unsigned(r_in);
      flop_rgb.g <= unsigned(g_in);
      flop_rgb.b <= unsigned(b_in);

      flop_rgb.valido <= valido_in;

      -- estagio 2 : multiplicacao
      conv_mult_aux.ypar1  := signed('0' & flop_rgb.r) * signed(fator_mult_y(0));
      conv_mult_aux.ypar2  := signed('0' & flop_rgb.g) * signed(fator_mult_y(1));
      conv_mult_aux.ypar3  := signed('0' & flop_rgb.b) * signed(fator_mult_y(2));
      conv_mult_aux.crpar1 := signed('0' & flop_rgb.r) * signed(fator_mult_cr(0));
      conv_mult_aux.crpar2 := signed('0' & flop_rgb.g) * signed(fator_mult_cr(1));
      conv_mult_aux.crpar3 := signed('0' & flop_rgb.b) * signed(fator_mult_cr(2));
      conv_mult_aux.cbpar1 := signed('0' & flop_rgb.r) * signed(fator_mult_cb(0));
      conv_mult_aux.cbpar2 := signed('0' & flop_rgb.g) * signed(fator_mult_cb(1));
      conv_mult_aux.cbpar3 := signed('0' & flop_rgb.b) * signed(fator_mult_cb(2));

      flop_mult_conv.valido <= flop_rgb.valido;
      flop_mult_conv.ypar1 <=
        conv_mult_aux.ypar1(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.ypar2 <=
        conv_mult_aux.ypar2(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.ypar3 <=
        conv_mult_aux.ypar3(MULT_SIGNAL_BIT downto MULT_LSB_BIT);

      flop_mult_conv.crpar1 <=
        conv_mult_aux.crpar1(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.crpar2 <=
        conv_mult_aux.crpar2(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.crpar3 <=
        conv_mult_aux.crpar3(MULT_SIGNAL_BIT downto MULT_LSB_BIT);

      flop_mult_conv.cbpar1 <=
        conv_mult_aux.cbpar1(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.cbpar2 <=
        conv_mult_aux.cbpar2(MULT_SIGNAL_BIT downto MULT_LSB_BIT);
      flop_mult_conv.cbpar3 <=
        conv_mult_aux.cbpar3(MULT_SIGNAL_BIT downto MULT_LSB_BIT);


      -- estagio 3 - fim da combinacao linear
      y_aux :=  flop_mult_conv.ypar1 + flop_mult_conv.ypar2 +
               flop_mult_conv.ypar3 + 16;
      cr_aux :=  flop_mult_conv.crpar1 + flop_mult_conv.crpar2 +
                flop_mult_conv.crpar3 + 128;
      cb_aux :=  flop_mult_conv.cbpar1 + flop_mult_conv.cbpar2 +
                flop_mult_conv.cbpar3 + 128;

      flop_conv_res.valido <= flop_mult_conv.valido;
      flop_conv_res.y      <= unsigned(y_aux(CALC_WORD_WIDTH-1 downto 0));
      flop_conv_res.cr     <= unsigned(cr_aux(CALC_WORD_WIDTH-1 downto 0));
      flop_conv_res.cb     <= unsigned(cb_aux(CALC_WORD_WIDTH-1 downto 0));

      -- estagio 4 - serializacao
      flop_serial.valid <= flop_conv_res.valido;
      if '1' = flop_conv_res.valido then
        case flop_serial.serialization_state is
          when SERIAL_ST_EVEN =>
            flop_serial.ycbcr_422           <= std_logic_vector(flop_conv_res.cb & flop_conv_res.y);
            flop_serial.cr                  <= std_logic_vector(flop_conv_res.cr);
            flop_serial.serialization_state <= SERIAL_ST_ODD;
          when SERIAL_ST_ODD =>
            flop_serial.ycbcr_422           <= flop_serial.cr & std_logic_vector(flop_conv_res.y);
            flop_serial.serialization_state <= SERIAL_ST_EVEN;
          when others => null;
        end case;
      end if;
      
    end if;
  end process clk_proc;
  

  ycrcb <= flop_serial.ycbcr_422;
  valido_out <= flop_serial.valid;
end architecture fpga;
