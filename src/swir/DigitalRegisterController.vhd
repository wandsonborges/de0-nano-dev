-- Inclus�o das bibliotecas necess�rias.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- Registradores de configura��o do sensor.
-- WIN - Seleciona se ser� configura��o de janela ou controle.
-- ITR - Integrate then readout mode
-- GC  - Cint Select
-- PW(1 0) - Power controle
-- I( 2 0 ) - Master current
-- AP(2 0 ) - CTIA Bias (Capactive TransImpedance Amplifier)
-- BW( 1 0 ) - CTIA Bandwidth Control
-- IMRO - Integrate/Readout Mode
-- NDRO - Integrate/Readout Mode Non-Destructive
-- TS(7-0 ) Built In Test Control
-- RO( 2 0 ) - Readout Order Control
-- OM(1 0 ) - Outputs Select
-- RE - Reference Output Enable
-- RST - Global Reset
-- OE_EN - Skimming Enable
-- WAX e WAY - Sele��o do in�cio da Linha/Coluna da janela.
-- WSX e WSY - Sele��o do tamanho da linha e da coluna da janela.

-- Para manter no modo Default, deve-se manter este controlador resetado.
-- Sa�da serial conforme protocolo especificado pelo datasheet.
-- Formato: StartBit | Win | 30 bits dados.
-- � necess�rio passar o FSYNC como forma de sincronizar o envio.
-- FSYNC tem que estar sincronizado com o CLOCK passado para esta entidade.
--
-- Este m�dulo altera o bit busy para indicar que o SetConfiguration pode ser deassertado.
entity DigitalRegisterController is
  port(
    
    -- Sinais de configura��o que deseja ser feito.
    WIN, ITR, GC, IMRO, NDRO, RE, RST, OE_EN : in STD_LOGIC;
    PW, BW, OM : in STD_LOGIC_VECTOR( 1 downto 0 ); 
    I, AP, RO : in STD_LOGIC_VECTOR( 2 downto 0 );
    TS : in STD_LOGIC_VECTOR( 7 downto 0 );
    WAX, WSX : in STD_LOGIC_VECTOR( 7 downto 0 );
    WAY, WSY : in STD_LOGIC_VECTOR( 6 downto 0 );

    -- Sianis de controle para funcionamento do m�dulo.
    Clock, nReset, FSYNC, SetConfiguration : in STD_LOGIC;
	SerialData, Busy : out STD_LOGIC;
	Debug : out STD_LOGIC_VECTOR( 1 downto 0 )
  );
end entity DigitalRegisterController;

architecture FSM_DigitalRegisterController of DigitalRegisterController is

  -- Declara os estados da m�quina de estados.
  type TYPE_STATE is ( state_waitValidFSYNC, state_startBit, state_sendData, state_FSYNCDelay );
  type TYPE_STATE_PULSE is ( statePulse_waitRise, statePulse_waitFall );

  -- Constantes.
  --
  -- RESET_EVENT : valor que ser� considerado reset.
  constant RESET_EVENT : STD_LOGIC := '0';
  -- CLOCK_EDGE : tipo de borda do clock 1 - subida, 0 - descida.
  constant CLOCK_EDGE : STD_LOGIC := '1';
  -- START_BIT/IDLE_BIT : valor do start BIT.
  constant START_BIT : STD_LOGIC := '1';
  constant IDLE_BIT  : STD_LOGIC := not START_BIT;
  -- VALID_DATA : valor que tem que estar o FSYNC para poder come�ar a enviar os dados.
  constant VALID_DATA : STD_LOGIC := '1';
  constant INVALID_DATA : STD_LOGIC := not VALID_DATA;
  -- CLOCK_CYCLES_VALID_DATA : n�mero de ciclos de clock ap�s a borda de subida do FSYNC que come�a a valer
  --                           os dados.
  constant CLOCK_CYCLES_VALID_DATA : INTEGER range 0 to 3 := 3;
  -- DATA_WIDTH : n�mero de bits que tem o dado total (incluindo WIN e excluindo StartBit ).
  constant DATA_WIDTH : INTEGER range 0 to  31 := 31;
  -- CONTROL_CONFIGURATION : constante que seleciona o modo de configura��o de controle.
  constant CONTROL_CONFIGURATION : STD_LOGIC := '0';
  -- START_PROCESS : constante que indica que � para iniciar o processo.
  constant START_PROCESS : STD_LOGIC := '1';  
  -- DIGITAL_REGISTER_CONTROLLER_BUSY/NOT_BUSY : indica��o de que o controlador est� ocupado,
  -- pode ser usado como feedback de que pode abaixar o SetConfiguration.
  constant DIGITAL_REGISTER_CONTROLLER_BUSY : STD_LOGIC := '1';
  constant DIGITAL_REGISTER_CONTROLLER_NOT_BUSY : STD_LOGIC := '0';

  -- Defini��o dos sinais que ser�o considerados como sendo os registradores de configura��o.
  signal DataConfiguration : STD_LOGIC_VECTOR( DATA_WIDTH-1 downto 0 );
  signal cycleCounter : INTEGER range 0 to DATA_WIDTH-1;

  -- Defini��o do sinal que faz armazena o estado.
  signal state : TYPE_STATE;
  signal statePulse : TYPE_STATE_PULSE;

  -- FSYNCPulse : sinal que gera um pulso sempre que ocorrer borda de subida no FSYNC.
  signal FSYNCPulse : STD_LOGIC;
  signal bitCounter : INTEGER range 0 to DATA_WIDTH-1;
  
begin

  -- Monta a mensagem da configura��o conforme o formato especificado. Os bits ser�o enviados serialmente.
  DataConfiguration <= WIN & ITR & GC & PW & I & AP & BW & IMRO & NDRO & TS & RO & OM & RE & RST & OE_EN when( WIN = CONTROL_CONFIGURATION ) else
                       WIN & WAX & WAY & WSX & WSY;
				
  -- Envia os bits de configurados do bit mais significativo para o menos.
  --SerialData <= START_BIT when( state = state_startBit ) else
  --              DataConfiguration( bitCounter ) when( state = state_sendData ) else
  --			  IDLE_BIT;
				
  Debug <= CONV_STD_LOGIC_VECTOR( TYPE_STATE'pos( state ), 2 );

  -- Indica que o controlador est� ocupado (de forma que ele j� aceitou a configura��o colocada anterioremnte).
  Busy <= DIGITAL_REGISTER_CONTROLLER_BUSY when( state /= state_waitValidFSYNC ) else
          DIGITAL_REGISTER_CONTROLLER_NOT_BUSY;

  -- Processo que implementa a m�quina de estados para poder configurar o sensor.
  FSM_PROCESS : process( Clock, nReset, FSYNCPulse )
  begin
    -- Quando houver um reset mant�m o estado inicial.
    if( nReset = RESET_EVENT ) then
	  state <= state_waitValidFSYNC;
	  SerialData <= IDLE_BIT;
	elsif( Clock'event and Clock = CLOCK_EDGE ) then
	  -- Verifica qual est� est� para poder fluir a m�quina de estados.
	  case( state ) is
	  
	    -- Espera pelo pr�ximo FSYNC (borda de subida) para poder iniciar o processo de cofnigura��o.
	    when state_waitValidFSYNC =>
		  SerialData <= IDLE_BIT;
		  if( FSYNCPulse = VALID_DATA and SetConfiguration = START_PROCESS ) then
		    state <= state_FSYNCDelay;
		  else
		    state <= state_waitValidFSYNC;
		  end if;
		  -- Zera o contador de ciclos para ser usado no pr�ximo estado.
		  cycleCounter <= 0;
		  
		-- Espera o n�mero de clocks necess�rios ap�s detectar a borda para iniciar o processo.
		when state_FSYNCDelay =>
		  if( cycleCounter = CLOCK_CYCLES_VALID_DATA-3 ) then
		    state <= state_startBit;
		    SerialData <= START_BIT;
	      else
	        state <= state_FSYNCDelay;
	        SerialData <= IDLE_BIT;
		    cycleCounter <= cycleCounter + 1;
		  end if;
		
		-- Executa um start bit antes dos dados.
		when state_startBit =>
		  state <= state_sendData;
		  -- Zera o contador de ciclos para ser usado no pr�ximo estado.
		  cycleCounter <= 0;
		
		  -- Come�a o bit counter com -2 j� que o primeiro bit j� est� sendo enviado.
		  bitCounter <= DATA_WIDTH-2;
		  SerialData <= DataConfiguration( DATA_WIDTH-1 );
		
		-- Envia os dados que est�o para ser configurados.
		when state_sendData =>
		  SerialData <= DataConfiguration( bitCounter );
		  if( bitCounter = 0 ) then
		    state <= state_waitValidFSYNC;
		  else
		    state <= state_sendData;
		    bitCounter <= bitCounter - 1;
		  end if;
		
		when others =>
		  state <= state_waitValidFSYNC;
	  
	  end case;
	
	end if;
  
  end process;

  -- Processo que gera um pulso quando ocorrer borda de subida do FSYNC.
  FSYNC_RISING_PULSE : process( Clock, nReset, FSYNC )
  begin
    if( nReset = RESET_EVENT ) then
      statePulse <= statePulse_waitRise;
      FSYNCPulse <= INVALID_DATA;
    elsif( Clock'event and Clock = CLOCK_EDGE ) then
      case( statePulse ) is
        -- Estado que espera at� que o FSYNC v� para o estado alto.
        when statePulse_waitRise =>
          if( FSYNC = VALID_DATA ) then
            FSYNCPulse <= VALID_DATA;
            statePulse <= statePulse_waitFall;
          else
            FSYNCPulse <= INVALID_DATA;
          end if;
        -- Estado que espera o FSYN ir para o estado baixo.
        when statePulse_waitFall =>
          FSYNCPulse <= INVALID_DATA;
          if( FSYNC = INVALID_DATA ) then
            statePulse <= statePulse_waitRise;
          end if;
      end case;
    end if;
  end process;

end FSM_DigitalRegisterController;
