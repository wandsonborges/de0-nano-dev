-- Sensor Interface
--
-- Arquivo de interface para o sensor com o módulo de memória.
-- 
-- Autor : Rafael Kioji Vivas Maeda.

library IEEE;
use IEEE.std_logic_1164.all;

-- Definição da interface do sensor.
-- Interface implementada baseada no sensor InfraRed.
entity ChangeDetector is
  port(
    -- Entradas de IO para configuração dos registradores.
    InputData : STD_LOGIC_VECTOR( 60 downto 0 );
 
    ControllerBusy, Clock, NotReset : in STD_LOGIC;
    SetConfiguration : out STD_LOGIC;
 
    Debug : out STD_LOGIC_VECTOR(1 downto 0)

  );
end ChangeDetector;

architecture FSM_ChangeDetector of ChangeDetector is

  -- Definição de tipos.
  -- 
  type TYPE_STATE is ( state_waitChange, state_waitAck, state_waitFinish );

  -- Constantes
  --
  -- RESET_EVENT: valor que representa um reset.
  constant RESET_EVENT : STD_LOGIC := '0';
  -- CLOCK_EDGE_TYPE: tipo de borda do clock. 1/0 => subida/descida
  constant CLOCK_EDGE_TYPE : STD_LOGIC := '1';
  -- NO_CHANGES_INPUT : constante que indica que não houve alteração nas entradas.
  constant UPDATING_INPUT : STD_LOGIC := '0';
  constant INPUT_UPDATED : STD_LOGIC := '1';
  constant CONTROLLER_BUSY : STD_LOGIC := '1';
  constant CONTROLLER_RELEASED : STD_LOGIC := not CONTROLLER_BUSY;
  constant SET_CONFIGUTATION : STD_LOGIC := '1';
  constant DONT_SET_CONFIGURATION : STD_LOGIC := not SET_CONFIGUTATION;
  

  -- Sinais de registro do sensor.
  signal lInput : STD_LOGIC_VECTOR( 60 downto 0 );

  signal lUpdatingInput : STD_LOGIC;
  signal state : TYPE_STATE;
  signal inputChanged : STD_LOGIC;

begin

  SetConfiguration <= SET_CONFIGUTATION when( state = state_waitAck ) else
                      DONT_SET_CONFIGURATION;

  --Debug <= conv_std_logic_vector(TYPE_STATE'pos(state), 2);

  -- Processo que ativa a configuração no sensor.
  SENSOR_CONFIG : process( Clock, NotReset, ControllerBusy, lInput, InputData )
  begin
    if( NotReset = RESET_EVENT ) then
      lUpdatingInput <= UPDATING_INPUT;
      state <= state_waitAck;
    elsif( Clock'event and Clock = CLOCK_EDGE_TYPE ) then
      case( state ) is
        when( state_waitChange ) =>
          lUpdatingInput <= INPUT_UPDATED;
          -- Se houver alguma alteração em algum dado de entrada, ativa a escrita no módulo.
          if( lInput /= InputData ) then
            state <= state_waitAck;
          else
            state <= state_waitChange;
          end if;
        -- Espera o controlador responder a configuração desejada a setar.
        when( state_waitAck ) =>
          lUpdatingInput <= UPDATING_INPUT;
          if( ControllerBusy = CONTROLLER_BUSY ) then
            state <= state_waitFinish;
          else
            state <= state_waitAck;
          end if;
         -- Espera o controlador terminar para poder ver se alterou.
         when( state_waitFinish ) =>
          lUpdatingInput <= INPUT_UPDATED;
           if( ControllerBusy = CONTROLLER_RELEASED ) then
             state <= state_waitChange;
           else
             state <= state_waitFinish;
           end if;
         when others =>
           state <= state_waitChange;
      end case;
    end if;
  end process;

  INPUT_UPDATE : block( Clock'event and Clock = CLOCK_EDGE_TYPE ) is
  begin
    lInput <= guarded InputData when(  lUpdatingInput = UPDATING_INPUT ) else
              unaffected;
  end block;
		

end FSM_ChangeDetector;
