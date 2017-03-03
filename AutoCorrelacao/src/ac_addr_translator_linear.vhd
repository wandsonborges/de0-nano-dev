--Tradutor de enderecos para a RAM onde estará
--armazenado os frames do sensor LUPA
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity ac_addr_translator_linear is
  
  generic (
    NUM_PIXELS          : integer            := 32; -- potencia de 2
    NUM_FRAMES          : integer            := 500;
    N_BITS_FRAME_SIZE   : integer            := 8;
    N_BITS_FRAME_INDEX  : integer            := 12;
    N_BITS_ADDR         : integer            := 20
    );

  port (
    n_in              : in  std_logic_vector(N_BITS_FRAME_SIZE-1 downto 0);
    w_in              : in  std_logic_vector(N_BITS_FRAME_INDEX-1 downto 0);
    endr_out          : out std_logic_vector(N_BITS_ADDR-1 downto 0));

end entity ac_addr_translator_linear;

architecture bhv of ac_addr_translator_linear is
  
  signal n_in_resized : unsigned(N_BITS_ADDR-1 downto 0);
  signal w_in_resized : unsigned(N_BITS_ADDR-1 downto 0);
  

  signal lin_mem_offset : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');
  signal buf_mem_offset : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');
  signal endr_out_aux   : unsigned(N_BITS_ADDR-1 downto 0) := (others => '0');

  signal out_of_limits : std_logic := '0';
  
begin  -- architecture bhv

  n_in_resized <= resize(unsigned(n_in), endr_out_aux'length);
  w_in_resized <= resize(unsigned(w_in), endr_out_aux'length);

  lin_mem_offset <= n_in_resized;
  buf_mem_offset <= shift_left(w_in_resized,integer(log2(real(NUM_PIXELS))));

  endr_out_aux <= resize((lin_mem_offset + buf_mem_offset), endr_out_aux'length);

  out_of_limits <= '1' when unsigned(n_in) > NUM_PIXELS-1
                   or unsigned(w_in) > NUM_FRAMES-1 else '0';

  endr_out <= std_logic_vector(endr_out_aux) when out_of_limits = '0' else (others => '1');

end architecture bhv;
