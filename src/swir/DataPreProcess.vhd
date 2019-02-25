-- DataPreProcess
--
-- Faz um pré-processamento da imagem capturada no sensor.
-- 
-- Autor : Rafael Kioji Vivas Maeda

library IEEE;
use IEEE.std_logic_1164.all;

-- Definição da interface do sensor.
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
  -- PROCESS_DISABLED : indicação de que o pre-processamento está desativado.
  -- Note que a ativação do processo é feita com lógica invertida.
  constant PROCESS_DISABLED : STD_LOGIC := '1';

  -- Declaração dos sinais que contém os tipos de pre-processamentos possíveis.
  signal NoPreProcess, DataOutInverted : STD_LOGIC_VECTOR( 7 downto 0 );

begin

  -- Se o processamento estiver ativado, libera o dado invertido, caso contrário
  -- coloca o dado normal.
  DataOut <= NoPreProcess when( nEnable = PROCESS_DISABLED ) else
             DataOutInverted;

  -- Sem pre-processamento a saída fica igual ao dado que entrou.
  NoPreProcess <= DataIn;

  -- Faz um processamento de inversão dos bits. (caso a imagem esteja
  -- revertida: preto está branco e branco está preto).
  INVERTER_BIT : for i in 0 to 7 generate
  begin
    DataOutInverted( i ) <= not DataIn( i );
  end generate;

end FSM_DataPreProcess;