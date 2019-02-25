-- Integration Time Controller
--
-- Arquivo que faz o controle do tempo de integra��o.
-- 

library IEEE;
use IEEE.std_logic_1164.all;

-- Defini��o da interface do controlador.
-- Interface que gera um sinal que indica se o Frame pode ser lido ou n�o.
entity IntegrationTimeController is
  port(
    Clock, NotReset, ReleaseFrame : in STD_LOGIC;
	FrameDone : out STD_LOGIC
  );
end IntegrationTimeController;

architecture FSM_IntegrationTimeController of IntegrationTimeController is

  -- Defini��o de constantes
  --
  -- CLOCK_EDGE_TYPE: tipo de borda do clock. 1/0 => subida/descida
  constant CLOCK_EDGE_TYPE : STD_LOGIC := '0';
  -- RESET_EVENT: valor que representa um reset.
  constant RESET_EVENT : STD_LOGIC := '0';
  -- FRAME_DONE_ASSERT/DEASSERT : constante que indica se o frame est� pronto ou n�o, respectivamente.
  constant FRAME_DONE_ASSERT : STD_LOGIC := '1';
  constant FRAME_DONE_DEASSERT : STD_LOGIC := '0';
  -- RELEASE_FRAME: constante que indica que um frame acabou de ser usado e pode ser atualizado no 
  --                sensor (fazer a carga novamente).
  constant RELEASE_FRAME : STD_LOGIC := '1';
  -- INTEGRATION_TIME_PERIOD : tempo de integra��o do sensor. Valor baseado no tempo de clock.
  --                    Este tempo � dado em m�ltiplos de um periodo correspondente ao clock do
  --                    fornecido (ex.: Clock sensor = 5MHz ent�o 10us precisa definir 50 ).
  constant INTEGRATION_TIME_PERIOD : INTEGER := 40000; --38000 2.5MHz * 0,016666 -
                                                       -- Valor marretado
  -- TIME_CORRECTION : constante de corre��o de tempo. Esta constante tem como objetivo o de corrigir
  --                   a contagem de tempo dado um erro no tempo de clock. Aproximar para cima. No caso
  --                   observado foi obtido um erro de 5ns para menos. Esta corre��o ser� aplicada na
  --                   contagem do tempo de integra��o.
  constant TIME_CORRECTION : INTEGER := 500;
  
  -- Defini��o de contadores.
  signal timeCounter : INTEGER;

begin

  -- Processo que gera o tempo de integra��o para o sensor.
  FSM_INTEGRATION_TIME : process( Clock, NotReset ) is
  begin
    -- Inicialmente ap�s ser resetado indica que n�o tem nenhum frame pronto.
    if( NotReset = RESET_EVENT ) then
	  FrameDone <= FRAME_DONE_DEASSERT;
	  timeCounter <= 0;
	-- Evento de clock que faz a contagem do tempo de integra��o.
	elsif( Clock'event and Clock = CLOCK_EDGE_TYPE ) then
	  -- Se o frame ja foi tratado faz a contagem de tempo para o tempo de integra��o.
	  -- Enquanto n�o tiver completado o tempo de integra��o mant�m o flag de frame Done desligado.
	  -- Quando o tempo de integra��o passar liga o flag de indica��o que o frame est� pronto.
	  if( ReleaseFrame = RELEASE_FRAME ) then
	    -- Espera o tempo com um fator de corre��o.
	    if( timeCounter = INTEGRATION_TIME_PERIOD+TIME_CORRECTION-1 ) then
		  FrameDone <= FRAME_DONE_ASSERT;
		else
		  timeCounter <= timeCounter + 1;
		  FrameDone <= FRAME_DONE_DEASSERT;
		end if;
      -- Se n�o tiver processado o frame, zera o contador.
	  else
		FrameDone <= FRAME_DONE_DEASSERT;
	    timeCounter <= 0;
	  end if;
	end if;
  end process;

end FSM_IntegrationTimeController;













