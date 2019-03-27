-- Greg Stitt
-- University of Florida
--
-- File: delay.vhd
-- Entity: delay
--
-- Description: This entity implements a chain of delay registers of generic
-- width. The length of the delay chain is specified by the "cycles" generic.
-- The entity also has an enable "en" that stalls the delay chain (i.e.
-- prevents registers from storing new values).
--
-- This example will give you a basic introduction to arrays.

library ieee;
use ieee.std_logic_1164.all;

entity delay_regs is
  generic(cycles :     positive;
          width  :     positive);
    port( clk    : in  std_logic;
          rst_n    : in  std_logic;
          en     : in  std_logic;
          input  : in  std_logic_vector(width-1 downto 0);
          output : out std_logic_vector(width-1 downto 0));
end delay_regs;

-- A structural architecture connecting together "cycles" registers to create
-- an appropriate delay.

architecture STR of delay_regs is

  -- If you look at delay.pdf, you will notice that there are "cycles"+1
  -- internal signals that are needed to connect the registers. We can't
  -- manually declare all these signals, because "cycles" can change for each
  -- instantiation of this entity. Therefore, we need to use an array. The
  -- following type declaration creates an array of cycles+1 elements, where
  -- each element is a "width"-bit std_logic_vector. Note that in a previous
  -- structural description for the ripple-carry adder, we did not need an
  -- array and simply used a std_logic_vector. The reason we didn't need an
  -- array is that each signal was one bit. In this case, each signal is
  -- "width" bits, so we need a custom array.

  type reg_array is array (0 to cycles) of std_logic_vector(width-1 downto 0);
  signal regs : reg_array;

begin

  regs(0) <= input;

  U_DELAY_REGS : for i in 0 to cycles-1 generate
    U_REG      : entity work.reg
      generic map (width => width)
      port map (clk      => clk,
                rst_n      => rst_n,
                en       => en,
                input    => regs(i),
                output   => regs(i+1));
  end generate U_DELAY_REGS;

  output <= regs(cycles);

end STR;


-- Here is an equivalent behavioral architecture that is equivalent to the
-- previous structural architecture. If you are wondering, which one to use,
-- the structural architecture has an advantage when instantiating complex
-- entities. In this case, a register can be described easily, so there isn't a
-- huge advantage. Also, the structural architecture has the advantage of
-- improved code reusage. For example, if you wanted to use the same registers
-- throughout a whole design and had to make changes to the register (e.g.,
-- switch from async reset to sync reset), with the structural architecture
-- you could simply change the register entity. With the behavioral
-- architecture, yo would have to change every signal that is inferred as
-- a register.
--
-- In general, I recommend the structural version.

architecture BHV of delay_regs is

  -- The behavioral version uses a smaller array because each element
  -- corresponds to a register instead of the connections between registers
  
  type reg_array is array (0 to cycles-1) of std_logic_vector(width-1 downto 0);
  signal regs : reg_array;
  
begin  -- BHV

  process(clk, rst_n)
  begin  
    if (rst_n = '0') then

      -- initialize the registers
      
      for i in 0 to cycles-1 loop
        regs(i) <= (others => '0');
      end loop;
    elsif (clk'event and clk = '1') then

      -- connect the input to the first register. Reg(0) is implemented as a
      -- register becase it is assigned on the rising clock edge.      
      if (en = '1') then
        regs(0) <= input;
      end if;

      -- create the register chain. Note that each regs() index is inferred as
      -- a register because it is assigned on a rising clock edge. Because of
      -- the reg(i+1) <= reg(i) relationship, this will create a series of
      -- registeres, which is exactly what we did in the structural version.
      -- The en makes sure the delay chain can be stalled.      
      for i in 0 to cycles-2 loop
        if (en = '1') then
          regs(i+1) <= regs(i);
        end if;
      end loop;      
      
    end if;
  end process;

  -- It is very important to do this outside the process. If we did this on the
  -- rising edge of the clock, we would create an additional register, which
  -- would make the delay more than what was requested by the "cycles" generic.
  
  output <= regs(cycles-1);
  
end BHV;
-- Greg Stitt
-- University of Florida

-- File: reg.vhd
-- Entity: reg
--
-- Description: This entity implements a register with generic width.
--

library ieee;
use ieee.std_logic_1164.all;

entity reg is
  generic (width :     positive  := 32);
  port(clk       : in  std_logic;
       rst_n       : in  std_logic;
       en        : in  std_logic;
       input     : in  std_logic_vector(width-1 downto 0);
       output    : out std_logic_vector(width-1 downto 0));
end reg;

architecture bhv of reg is
begin
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      output   <= (others => '0');
    elsif (clk = '1' and clk'event) then
      if (en = '1') then
        output <= input;
      end if;
    end if;
  end process;
end bhv;
