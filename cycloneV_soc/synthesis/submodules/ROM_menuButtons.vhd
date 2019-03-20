-------------------------------------------------------------------------------
-- ROM_menuButtons.vhd
--   2017-10-10 // FDaldegan
--   Gerado a partir de ROM_Pallete_rgb_standard.vhd.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Bibliotecas
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.all;

-------------------------------------------------------------------------------
-- Entidade
-------------------------------------------------------------------------------
entity ROM_menuButtons is
  generic (
    SIMULATION    : BOOLEAN := false;
    ADDRESS_WIDTH : INTEGER := 16
    );
  port (
    clock   : in  STD_LOGIC;
    address : in  STD_LOGIC_VECTOR(ADDRESS_WIDTH-1 DOWNTO 0);
    q	    : out STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
end entity ROM_menuButtons;

-------------------------------------------------------------------------------
-- Arquitetura
-------------------------------------------------------------------------------
architecture syn of ROM_menuButtons is

  -----------------------------------------------------------------------------
  -- Declaracao de componentes
  -----------------------------------------------------------------------------

  -- Bloco de memoria RAM interna
  component altsyncram
    generic (
      address_aclr_a 	     : STRING;
      init_file              : STRING;
      intended_device_family : STRING;
      lpm_hint		     : STRING;
      lpm_type		     : STRING;
      numwords_a	     : NATURAL;
      operation_mode	     : STRING;
      outdata_aclr_a	     : STRING;
      outdata_reg_a	     : STRING;
      widthad_a		     : NATURAL;
      width_a		     : NATURAL;
      width_byteena_a	     : NATURAL
      );
    port (
      clock0	: in  STD_LOGIC ;
      address_a	: in  STD_LOGIC_VECTOR (widthad_a-1 downto 0);
      q_a	: out STD_LOGIC_VECTOR (0 downto 0)
      );
  end component altsyncram;

  -----------------------------------------------------------------------------
  -- Sinais
  -----------------------------------------------------------------------------
  signal sub_wire0 : STD_LOGIC_VECTOR(0 downto 0);
  
  -----------------------------------------------------------------------------

begin

  -----------------------------------------------------------------------------
  -- Instancia de bloco de memoria RAM interna, inicializada com um arquivo
  -- .mif que contem os botoes
  -----------------------------------------------------------------------------

  SIMULATION_PROFILE : if SIMULATION = true generate
    altsyncram_sim : component altsyncram
      generic map (
        address_aclr_a         => "NONE",
        init_file              => "../../src/menu.mif",
        intended_device_family => "Cyclone",
        lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
        lpm_type               => "altsyncram",
        numwords_a             => 2**ADDRESS_WIDTH,
        operation_mode         => "ROM",
        outdata_aclr_a         => "NONE",
        outdata_reg_a          => "UNREGISTERED",
        widthad_a              => ADDRESS_WIDTH,
        width_a                => 1,
        width_byteena_a        => 1
        )
      PORT MAP (
        clock0    => clock,
        address_a => address,
        q_a       => sub_wire0
        );
    end generate SIMULATION_PROFILE;

  SYNTHESIS_PROFILE : if SIMULATION = false generate
    altsyncram_1 : component altsyncram
      generic map (
        address_aclr_a         => "NONE",
        init_file              => "../src/menu.mif",
        intended_device_family => "Cyclone",
        lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
        lpm_type               => "altsyncram",
        numwords_a             => 2**ADDRESS_WIDTH,
        operation_mode         => "ROM",
        outdata_aclr_a         => "NONE",
        outdata_reg_a          => "UNREGISTERED",
        widthad_a              => ADDRESS_WIDTH,
        width_a                => 1,
        width_byteena_a        => 1
        )
      PORT MAP (
        clock0    => clock,
        address_a => address,
        q_a       => sub_wire0
        );
  end generate SYNTHESIS_PROFILE;
  
  -----------------------------------------------------------------------------
  -- Wiring
  -----------------------------------------------------------------------------
  q <= sub_wire0(0 downto 0);

end architecture syn;

