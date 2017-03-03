--Tradutor de enderecos para a RAM onde estará
--armazenado os frames do sensor LUPA
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity ac_addr_translator is
  
  generic (
    NUM_COLUNAS         : integer            := 16; --potencia de 2
    NUM_LINHAS          : integer            := 2;  --potencia de 2
    NUM_FRAMES          : integer            := 500;
    N_BITS_FRAME_SIZE   : integer            := 8;
    N_BITS_FRAME_INDEX  : integer            := 12;
    N_BITS_ADDR         : integer            := 20
    );

  port (
    x_in              : in  std_logic_vector(N_BITS_FRAME_SIZE-1 downto 0);
    y_in              : in  std_logic_vector(N_BITS_FRAME_SIZE-1 downto 0);
    w_in              : in  std_logic_vector(N_BITS_FRAME_INDEX-1 downto 0);
    endr_out          : out std_logic_vector(N_BITS_ADDR-1 downto 0));

end entity ac_addr_translator;

architecture bhv of ac_addr_translator is
  signal x_in_resized : unsigned(N_BITS_ADDR-1 downto 0);
  signal y_in_resized : unsigned(N_BITS_ADDR-1 downto 0);
  signal w_in_resized : unsigned(N_BITS_ADDR-1 downto 0);
  
  signal col_mem_offset : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');
  signal lin_mem_offset : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');
  signal buf_mem_offset : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');
  signal endr_out_aux   : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');

  signal out_of_limits : std_logic := '0';
  
begin  -- architecture bhv

  x_in_resized <= resize(unsigned(x_in), endr_out_aux'length);
  y_in_resized <= resize(unsigned(y_in), endr_out_aux'length);
  w_in_resized <= resize(unsigned(w_in), endr_out_aux'length);

  col_mem_offset <= x_in_resized;
  lin_mem_offset <= shift_left(y_in_resized,integer(log2(real(NUM_COLUNAS))));
  buf_mem_offset <= shift_left(w_in_resized,integer(log2(real(NUM_LINHAS*NUM_COLUNAS))));

  endr_out_aux <= resize((col_mem_offset + lin_mem_offset + buf_mem_offset), endr_out_aux'length);

  out_of_limits <= '1' when unsigned(x_in) > NUM_COLUNAS-1 or unsigned(y_in) > NUM_LINHAS-1
                   or unsigned(w_in) > NUM_FRAMES-1 else '0';

  endr_out <= std_logic_vector(endr_out_aux) when out_of_limits = '0' else (others => '1');

end architecture bhv;
