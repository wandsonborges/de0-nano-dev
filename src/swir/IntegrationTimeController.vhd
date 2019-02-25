-- Integration Time Controller
--
-- Arquivo que faz o controle do tempo de integração.
-- 

library IEEE;
use IEEE.std_logic_1164.all;

-- Definição da interface do controlador.
-- Interface que gera um sinal que indica se o Frame pode ser lido ou não.
entity IntegrationTimeController is
  port(
    Clock, NotReset, ReleaseFrame : in STD_LOGIC;
	FrameDone : out STD_LOGIC
  );
end IntegrationTimeController;

architecture FSM_IntegrationTimeController of IntegrationTimeController is

  -- Definição de constantes
  --
  -- CLOCK_EDGE_TYPE: tipo de borda do clock. 1/0 => subida/descida
  constant CLOCK_EDGE_TYPE : STD_LOGIC := '0';
  -- RESET_EVENT: valor que representa um reset.
  constant RESET_EVENT : STD_LOGIC := '0';
  -- FRAME_DONE_ASSERT/DEASSERT : constante que indica se o frame está pronto ou não, respectivamente.
  constant FRAME_DONE_ASSERT : STD_LOGIC := '1';
  constant FRAME_DONE_DEASSERT : STD_LOGIC := '0';
  -- RELEASE_FRAME: constante que indica que um frame acabou de ser usado e pode ser atualizado no 
  --                sensor (fazer a carga novamente).
  constant RELEASE_FRAME : STD_LOGIC := '1';
  -- INTEGRATION_TIME_PERIOD : tempo de integração do sensor. Valor baseado no tempo de clock.
  --                    Este tempo é dado em múltiplos de um periodo correspondente ao clock do
  --                    fornecido (ex.: Clock sensor = 5MHz então 10us precisa definir 50 ).
  constant INTEGRATION_TIME_PERIOD : INTEGER := 40000; --38000 2.5MHz * 0,016666 -
                                                       -- Valor marretado
  -- TIME_CORRECTION : constante de correção de tempo. Esta constante tem como objetivo o de corrigir
  --                   a contagem de tempo dado um erro no tempo de clock. Aproximar para cima. No caso
  --                   observado foi obtido um erro de 5ns para menos. Esta correção será aplicada na
  --                   contagem do tempo de integração.
  constant TIME_CORRECTION : INTEGER := 500;
  
  -- Definição de contadores.
  signal timeCounter : INTEGER;

begin

  -- Processo que gera o tempo de integração para o sensor.
  FSM_INTEGRATION_TIME : process( Clock, NotReset ) is
  begin
    -- Inicialmente após ser resetado indica que não tem nenhum frame pronto.
    if( NotReset = RESET_EVENT ) then
	  FrameDone <= FRAME_DONE_DEASSERT;
	  timeCounter <= 0;
	-- Evento de clock que faz a contagem do tempo de integração.
	elsif( Clock'event and Clock = CLOCK_EDGE_TYPE ) then
	  -- Se o frame ja foi tratado faz a contagem de tempo para o tempo de integração.
	  -- Enquanto não tiver completado o tempo de integração mantém o flag de frame Done desligado.
	  -- Quando o tempo de integração passar liga o flag de indicação que o frame está pronto.
	  if( ReleaseFrame = RELEASE_FRAME ) then
	    -- Espera o tempo com um fator de correção.
	    if( timeCounter = INTEGRATION_TIME_PERIOD+TIME_CORRECTION-1 ) then
		  FrameDone <= FRAME_DONE_ASSERT;
		else
		  timeCounter <= timeCounter + 1;
		  FrameDone <= FRAME_DONE_DEASSERT;
		end if;
      -- Se não tiver processado o frame, zera o contador.
	  else
		FrameDone <= FRAME_DONE_DEASSERT;
	    timeCounter <= 0;
	  end if;
	end if;
  end process;

end FSM_IntegrationTimeController;













