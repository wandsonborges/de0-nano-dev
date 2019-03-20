------------------------------------------------------------------------------
-- Title      : sobel
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sobel.vhd
-- Author     :   <mdrumond@TESLA>
-- Company    : 
-- Created    : 2013-11-13
-- Last update: 2014-01-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implementa o sobel e aplica o cordic no resultado, obtendo
-- os derivativos como saida
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-11-13  1.0      mdrumond        Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uteis.all;

entity sobel is
  
  generic (
    NUMERO_COLUNAS           : integer := 320;
    LARGURA_CONTADOR_COLUNAS : integer := 9;
    LARGURA_PIXEL       : integer := 8);

  port (
    clk, rst_n             : in  std_logic;
    pixel_in               : in  pixel_t;
    valido_in              : in  std_logic;
    inicio_linha_in        : in  std_logic;
    segundo_pixel_linha_in : in  std_logic;
    apos_fim_linha_in      : in  std_logic;
    primeira_linha_in      : in  std_logic;
    segunda_linha_in       : in  std_logic;
    apos_ultima_linha_in   : in  std_logic;
    inicio_linha_out       : out std_logic;
    fim_linha_out          : out std_logic;
    dx_out, dy_out         : out std_logic_vector(LARGURA_PIXEL+3-1 downto 0);
    valido_out             : out std_logic);

end entity sobel;

architecture fpga of sobel is
  constant LARGURA_DADOS : integer := LARGURA_PIXEL+3;
  subtype sobel_t is signed(LARGURA_DADOS-1 downto 0);

  type flop_pre_buffer_t is record
    pixel_wr_in         : pixel_t;
    buffer_wr_en        : std_logic;
    buffer_addr         : unsigned(LARGURA_CONTADOR_COLUNAS-1 downto 0);
    buffer_line_sl      : unsigned(1 downto 0);
    inicio_linha        : std_logic;
    segundo_pixel_linha : std_logic;
    apos_fim_linha      : std_logic;
    primeira_linha      : std_logic;
    segunda_linha       : std_logic;
    apos_ultima_linha   : std_logic;
  end record flop_pre_buffer_t;
  constant DEF_FLOP_PRE_BUFFER : flop_pre_buffer_t := (
    buffer_wr_en        => '0',
    buffer_line_sl      => (others => '0'),
    buffer_addr         => (others => '0'),
    pixel_wr_in         => (others => '0'),
    inicio_linha        => '0',
    segundo_pixel_linha => '0',
    apos_fim_linha      => '0',
    primeira_linha      => '0',
    segunda_linha       => '0',
    apos_ultima_linha   => '0');
  signal flop_pre_buffer : flop_pre_buffer_t := DEF_FLOP_PRE_BUFFER;

  type flop_atraso_leitura_t is record
    pixel_wr_in         : pixel_t;
    inicio_linha        : std_logic;
    segundo_pixel_linha : std_logic;
    apos_fim_linha      : std_logic;
    primeira_linha      : std_logic;
    segunda_linha       : std_logic;
    apos_ultima_linha   : std_logic;
    rd_valido           : std_logic;
  end record flop_atraso_leitura_t;
  constant DEF_ATRASO_LEITURA : flop_atraso_leitura_t := (
    pixel_wr_in         => (others => '0'),
    inicio_linha        => '0',
    segundo_pixel_linha => '0',
    apos_fim_linha      => '0',
    primeira_linha      => '0',
    segunda_linha       => '0',
    apos_ultima_linha   => '0',
    rd_valido           => '0');
  signal flop_atraso_leitura : flop_atraso_leitura_t := DEF_ATRASO_LEITURA;

  type flop_pre_kernel_t is record
    valido                                  : std_logic;
    inicio_linha, fim_linha                 : std_logic;
    primeira_linha, ultima_linha            : std_logic;
    lin_ant_pix_atual, lin_ant_pix_prox     : pixel_t;
    lin_atual_pix_atual, lin_atual_pix_prox : pixel_t;
    lin_prox_pix_atual, lin_prox_pix_prox   : pixel_t;
  end record flop_pre_kernel_t;
  constant DEF_FLOP_PRE_KERNEL : flop_pre_kernel_t := (
    valido              => '0',
    primeira_linha      => '0',
    ultima_linha        => '0',
    inicio_linha        => '0',
    fim_linha           => '0',
    lin_ant_pix_prox    => (others => '0'),
    lin_ant_pix_atual   => (others => '0'),
    lin_atual_pix_prox  => (others => '0'),
    lin_atual_pix_atual => (others => '0'),
    lin_prox_pix_prox   => (others => '0'),
    lin_prox_pix_atual  => (others => '0'));
  signal flop_pre_kernel : flop_pre_kernel_t := DEF_FLOP_PRE_KERNEL;

  -- buffer de calculo guarda 9 valores
  type kernel_t is array (0 to 8) of unsigned(C_LARGURA_PIXEL-1 downto 0);


  signal buffer_out_atual_linha : pixel_t;
  signal buffer_out_ant_linha   : pixel_t;

  type flop_kernel_t is record
    kernel                       : kernel_t;
    valido                       : std_logic;
    inicio_linha, fim_linha      : std_logic;
    primeira_linha, ultima_linha : std_logic;
  end record flop_kernel_t;
  constant DEF_FLOP_KERNEL : flop_kernel_t := (
    kernel         => (others => (others => '0')),
    valido         => '0',
    primeira_linha => '0',
    ultima_linha   => '0',
    inicio_linha   => '0',
    fim_linha      => '0');
  signal flop_kernel : flop_kernel_t := DEF_FLOP_KERNEL;

  type flop_deriv_out_t is record
    dx, dy                  : sobel_t;
    valido                  : std_logic;
    inicio_linha, fim_linha : std_logic;
  end record flop_deriv_out_t;
   constant DEF_FLOP_DERIV_OUT : flop_deriv_out_t := (
    dx           => (others => '0'),
    dy           => (others => '0'),
    valido       => '0',
    inicio_linha => '0',
    fim_linha    => '0');
  signal flop_deriv_out : flop_deriv_out_t := DEF_FLOP_DERIV_OUT;

  constant LARGURA_CALC_SOBEL : integer := LARGURA_DADOS;
  -- purpose: Implementa o sobel
  function calcula_sobel_dx (
    signal kernel : in  kernel_t)
    return sobel_t is
    variable dx_aux : sobel_t;
  begin  -- procedure calcula_cordic
    dx_aux := signed(resize(kernel(0), LARGURA_CALC_SOBEL) +
                     shift_left(resize(kernel(3), LARGURA_CALC_SOBEL), 1) +
                     resize(kernel(6), LARGURA_CALC_SOBEL)) -
              signed(resize(kernel(2), LARGURA_CALC_SOBEL) +
                     shift_left(resize(kernel(5), LARGURA_CALC_SOBEL), 1) +
                     resize(kernel(8), LARGURA_CALC_SOBEL));

    return dx_aux;
  end function calcula_sobel_dx;

  function calcula_sobel_dy (
    signal kernel : in  kernel_t)
    return sobel_t is
    variable dy_aux : sobel_t;
  begin  -- procedure calcula_cordic
    dy_aux := signed(resize(kernel(6), LARGURA_CALC_SOBEL) +
                     shift_left(resize(kernel(7), LARGURA_CALC_SOBEL), 1) +
                     resize(kernel(8), LARGURA_CALC_SOBEL)) -
              signed(resize(kernel(0), LARGURA_CALC_SOBEL) +
                     shift_left(resize(kernel(1), LARGURA_CALC_SOBEL), 1) +
                     resize(kernel(2), LARGURA_CALC_SOBEL));
    return dy_aux;
  end function calcula_sobel_dy;

  -- purpose: Faz o shift do kernel
  function shift_kernel (
    kernel                                         : kernel_t;
    pix_linha_ant, pix_linha_atual, pix_linha_prox : pixel_t)
    return kernel_t is
  begin  -- procedure shift_kernel
    return (
      0 => kernel(1), 1 => kernel(2),
      2 => unsigned(pix_linha_ant),
      3 => kernel(4), 4 => kernel(5),
      5 => unsigned(pix_linha_atual),
      6 => kernel(7), 7 => kernel(8),
      8 => unsigned(pix_linha_prox));
  end function shift_kernel;

begin  -- architecture fpga

  -- purpose: Implementa o sobel
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  clk_proc : process (clk, rst_n) is
  begin  -- process clk_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      flop_pre_buffer     <= DEF_FLOP_PRE_BUFFER;
      flop_atraso_leitura <= DEF_ATRASO_LEITURA;
      flop_pre_kernel     <= DEF_FLOP_PRE_KERNEL;
      flop_kernel         <= DEF_FLOP_KERNEL;
      flop_deriv_out      <= DEF_FLOP_DERIV_OUT;
    elsif clk'event and clk = '1' then  -- rising clock edge
      flop_pre_buffer.inicio_linha        <= inicio_linha_in;
      flop_pre_buffer.segundo_pixel_linha <= segundo_pixel_linha_in;
      flop_pre_buffer.apos_fim_linha      <= apos_fim_linha_in;
      flop_pre_buffer.primeira_linha      <= primeira_linha_in;
      flop_pre_buffer.segunda_linha       <= segunda_linha_in;
      flop_pre_buffer.apos_ultima_linha   <= apos_ultima_linha_in;
      flop_pre_buffer.buffer_wr_en        <= valido_in;
      flop_pre_buffer.pixel_wr_in         <= pixel_in;

      if ('1' = valido_in) or ('1' = apos_ultima_linha_in) then
        if ('1' = inicio_linha_in) or ('1' = apos_fim_linha_in) then
          flop_pre_buffer.buffer_addr <= (others => '0');
        else
          flop_pre_buffer.buffer_addr <= flop_pre_buffer.buffer_addr + 1;
        end if;
      end if;

      if '1' = apos_fim_linha_in then
        flop_pre_buffer.buffer_line_sl <= flop_pre_buffer.buffer_line_sl + 1;
        if 2 = flop_pre_buffer.buffer_line_sl then
          flop_pre_buffer.buffer_line_sl <= (others => '0');
        end if;
      end if;
      -- a leitura e valida se:  um pixel que nao eh da primeira linha foi escrito
      -- no buffer ou está escrevendo a ultima linha
      flop_atraso_leitura.rd_valido
        <= (flop_pre_buffer.buffer_wr_en and (not flop_pre_buffer.primeira_linha)) or
        (flop_pre_buffer.apos_ultima_linha);

      flop_atraso_leitura.inicio_linha        <= flop_pre_buffer.inicio_linha;
      flop_atraso_leitura.segundo_pixel_linha <= flop_pre_buffer.segundo_pixel_linha;
      flop_atraso_leitura.apos_fim_linha      <= flop_pre_buffer.apos_fim_linha;
      flop_atraso_leitura.primeira_linha      <= flop_pre_buffer.primeira_linha;
      flop_atraso_leitura.segunda_linha       <= flop_pre_buffer.segunda_linha;
      flop_atraso_leitura.apos_ultima_linha   <= flop_pre_buffer.apos_ultima_linha;
      flop_atraso_leitura.pixel_wr_in         <= flop_pre_buffer.pixel_wr_in;

      -- O kernel eh construido com um pixel e uma linha de atraso em relacao
      -- aos pixeis lidos. Por isso nos mudamos o nome dos sinais.
      flop_pre_kernel.inicio_linha   <= flop_atraso_leitura.segundo_pixel_linha;
      flop_pre_kernel.fim_linha      <= flop_atraso_leitura.apos_fim_linha;
      flop_pre_kernel.primeira_linha <= flop_atraso_leitura.segunda_linha;
      flop_pre_kernel.ultima_linha   <= flop_atraso_leitura.apos_ultima_linha;

      if '1' = flop_atraso_leitura.rd_valido then
        flop_pre_kernel.lin_prox_pix_prox   <= flop_atraso_leitura.pixel_wr_in;
        flop_pre_kernel.lin_prox_pix_atual  <= flop_pre_kernel.lin_prox_pix_prox;
        flop_pre_kernel.lin_atual_pix_prox  <= buffer_out_atual_linha;
        flop_pre_kernel.lin_atual_pix_atual <= flop_pre_kernel.lin_atual_pix_prox;
        flop_pre_kernel.lin_ant_pix_prox    <= buffer_out_ant_linha;
        flop_pre_kernel.lin_ant_pix_atual   <= flop_pre_kernel.lin_ant_pix_prox;
      end if;

      if '1' = flop_atraso_leitura.rd_valido then
        if '1' = flop_atraso_leitura.inicio_linha then
          flop_pre_kernel.valido <= '0';
        else
          flop_pre_kernel.valido <= '1';
        end if;
      elsif ('1' = flop_atraso_leitura.apos_fim_linha) and
        ('0' = flop_atraso_leitura.primeira_linha) then
        flop_pre_kernel.valido <= '1';
      else
        flop_pre_kernel.valido <= '0';
      end if;


      flop_kernel.inicio_linha   <= flop_pre_kernel.inicio_linha and flop_pre_kernel.valido;
      flop_kernel.fim_linha      <= flop_pre_kernel.fim_linha and flop_pre_kernel.valido;
      flop_kernel.primeira_linha <= flop_pre_kernel.primeira_linha and flop_pre_kernel.valido;
      flop_kernel.ultima_linha   <= flop_pre_kernel.ultima_linha and flop_pre_kernel.valido;
      flop_kernel.valido         <= flop_pre_kernel.valido;

      if '1' = flop_pre_kernel.valido then
        if '1' = flop_pre_kernel.fim_linha then
          flop_kernel.kernel <= shift_kernel(flop_kernel.kernel,
                                             std_logic_vector(flop_kernel.kernel(2)),
                                             std_logic_vector(flop_kernel.kernel(5)),
                                             std_logic_vector(flop_kernel.kernel(8)));
        elsif '1' = flop_pre_kernel.primeira_linha then
          if '1' = flop_pre_kernel.inicio_linha then
            flop_kernel.kernel <= (
              0 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              1 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              2 => unsigned(flop_pre_kernel.lin_atual_pix_prox),
              3 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              4 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              5 => unsigned(flop_pre_kernel.lin_atual_pix_prox),
              6 => unsigned(flop_pre_kernel.lin_prox_pix_atual),
              7 => unsigned(flop_pre_kernel.lin_prox_pix_atual),
              8 => unsigned(flop_pre_kernel.lin_prox_pix_prox));
          else
            flop_kernel.kernel <= shift_kernel(flop_kernel.kernel, flop_pre_kernel.lin_atual_pix_prox,
                                               flop_pre_kernel.lin_atual_pix_prox,
                                               flop_pre_kernel.lin_prox_pix_prox);
          end if;
        elsif '1' = flop_pre_kernel.ultima_linha then
          if '1' = flop_pre_kernel.inicio_linha then
            flop_kernel.kernel <= (
              0 => unsigned(flop_pre_kernel.lin_ant_pix_atual),
              1 => unsigned(flop_pre_kernel.lin_ant_pix_atual),
              2 => unsigned(flop_pre_kernel.lin_ant_pix_prox),
              3 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              4 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              5 => unsigned(flop_pre_kernel.lin_atual_pix_prox),
              6 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              7 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              8 => unsigned(flop_pre_kernel.lin_atual_pix_prox));
          else
            flop_kernel.kernel <= shift_kernel(flop_kernel.kernel, flop_pre_kernel.lin_ant_pix_prox,
                                               flop_pre_kernel.lin_atual_pix_prox,
                                               flop_pre_kernel.lin_atual_pix_prox);
          end if;
        else
          if '1' = flop_pre_kernel.inicio_linha then
            flop_kernel.kernel <= (
              0 => unsigned(flop_pre_kernel.lin_ant_pix_atual),
              1 => unsigned(flop_pre_kernel.lin_ant_pix_atual),
              2 => unsigned(flop_pre_kernel.lin_ant_pix_prox),
              3 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              4 => unsigned(flop_pre_kernel.lin_atual_pix_atual),
              5 => unsigned(flop_pre_kernel.lin_atual_pix_prox),
              6 => unsigned(flop_pre_kernel.lin_prox_pix_atual),
              7 => unsigned(flop_pre_kernel.lin_prox_pix_atual),
              8 => unsigned(flop_pre_kernel.lin_prox_pix_prox));
          else
            flop_kernel.kernel <= shift_kernel(flop_kernel.kernel, flop_pre_kernel.lin_ant_pix_prox,
                                               flop_pre_kernel.lin_atual_pix_prox,
                                               flop_pre_kernel.lin_prox_pix_prox);
          end if;
        end if;
        
      end if;

      flop_deriv_out.dx <= calcula_sobel_dx(flop_kernel.kernel);
      flop_deriv_out.dy <= calcula_sobel_dy(flop_kernel.kernel);
      flop_deriv_out.valido       <= flop_kernel.valido;
      flop_deriv_out.inicio_linha <= flop_kernel.inicio_linha;
      flop_deriv_out.fim_linha    <= flop_kernel.fim_linha;

      dx_out <= std_logic_vector(flop_deriv_out.dx);
      dy_out <= std_logic_vector(flop_deriv_out.dy);
      inicio_linha_out <= flop_deriv_out.inicio_linha;
      fim_linha_out <= flop_deriv_out.fim_linha;
      valido_out <= flop_deriv_out.valido;
    end if;
  end process clk_proc;
  
  filter_line_buffer_1 : entity work.filter_line_buffer
    generic map (
      NUMERO_COLUNAS           => NUMERO_COLUNAS,
      LARGURA_CONTADOR_COLUNAS => LARGURA_CONTADOR_COLUNAS)
    port map (
      clk                    => clk,
      rst_n                  => rst_n,
      pixel_in               => flop_pre_buffer.pixel_wr_in,
      buffer_wr_sl           => std_logic_vector(flop_pre_buffer.buffer_line_sl),
      pix_wr_en              => flop_pre_buffer.buffer_wr_en,
      pixel_wr_addr          => std_logic_vector(flop_pre_buffer.buffer_addr),
      pixel_rd_addr          => std_logic_vector(flop_pre_buffer.buffer_addr),
      pixel_out_atual_linha  => buffer_out_atual_linha,
      pixel_out_ultima_linha => buffer_out_ant_linha);

end architecture fpga;
