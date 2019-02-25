-- DataPreProcess
--
-- Faz um pr�-processamento da imagem capturada no sensor.
-- 
-- Autor : Rafael Kioji Vivas Maeda

library IEEE;
use IEEE.std_logic_1164.all;

-- Defini��o da interface do sensor.
-- Interface implementada baseada no sensor InfraRed.
entity DataPreProcess is
  port(
    nEnable  : in STD_LOGIC;
    DataIn  : in STD_LOGIC_VECTOR( 7 downto 0 );
    DataOut : out STD_LOGIC_VECTOR( 7 downto 0 )
  );
end DataPreProcess;

architecture FSM_DataPreProcess of DataPreProcess is

  -- Constantes.
  -- 
  -- PROCESS_DISABLED : indica��o de que o pre-processamento est� desativado.
  -- Note que a ativa��o do processo � feita com l�gica invertida.
  constant PROCESS_DISABLED : STD_LOGIC := '1';

  -- Declara��o dos sinais que cont�m os tipos de pre-processamentos poss�veis.
  signal NoPreProcess, DataOutInverted : STD_LOGIC_VECTOR( 7 downto 0 );

begin

  -- Se o processamento estiver ativado, libera o dado invertido, caso contr�rio
  -- coloca o dado normal.
  DataOut <= NoPreProcess when( nEnable = PROCESS_DISABLED ) else
             DataOutInverted;

  -- Sem pre-processamento a sa�da fica igual ao dado que entrou.
  NoPreProcess <= DataIn;

  -- Faz um processamento de invers�o dos bits. (caso a imagem esteja
  -- revertida: preto est� branco e branco est� preto).
  INVERTER_BIT : for i in 0 to 7 generate
  begin
    DataOutInverted( i ) <= not DataIn( i );
  end generate;

end FSM_DataPreProcess;