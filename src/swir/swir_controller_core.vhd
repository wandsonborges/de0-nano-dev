-- SWIR_CONTROLLER
--
-- Autor: rodrigo.oliveira@TESLA
-- OBS: Baseado nos cÃ¯Â¿Â½digos da V200.
--      Configuracoes dos registradores internos do sensor estao
--      comentadas


library IEEE;
use IEEE.std_logic_1164.all;

-- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o da interface do sensor.
-- Interface implementada baseada no sensor InfraRed.
entity swir_controller_core is
  port(

    -- Entradas para configuraÃ¯Â¿Â½Ã¯Â¿Â½o interna de pre-processamento de imagem.
    nInvertPattern : in STD_LOGIC;

    -- Entradas de interface com o sensor.
    DataIn : in STD_LOGIC_VECTOR( 7 downto 0 );
    swir_registers : in STD_LOGIC_VECTOR( 31 downto 0 );
    NotReset : in STD_LOGIC;

    -- Saidas de interface com a memÃ¯Â¿Â½ria.
    WriteMem : out STD_LOGIC;

    --Reseta registradores sensor
    RST_Sensor : in STD_LOGIC;
    OE_EN     : in STD_LOGIC;
    AP , I : in STD_LOGIC_VECTOR(2 downto 0);
    BW, PW, OM : in STD_LOGIC_VECTOR(1 downto 0);
    
    -- StartWriteMem, WriteClock : out STD_LOGIC;
    DataOut : out STD_LOGIC_VECTOR( 7 downto 0 );
    -- Saidas de controle do sensor.
    FSYNC, LSYNC : out STD_LOGIC;
    EOF : out STD_LOGIC;
    DataCodeMode : out STD_LOGIC; --default mode
    OutSelection : out STD_LOGIC_VECTOR( 3 downto 0 );
    Pixel_Clock : in STD_LOGIC;
    Sensor_Clock : in STD_LOGIC
    
    --AD_Clock : out STD_LOGIC
    -- Saidas de indicaÃ¯Â¿Â½Ã¯Â¿Â½o internas.
    
   -- Debug : Comentar na versÃ¯Â¿Â½o final.
   --debugState : out STD_LOGIC_VECTOR( 2 downto 0 )
    );
end swir_controller_core;

architecture FSM_SensorInterface of swir_controller_core is

  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de componentes
  -- IntegrationTimeController: controlador de integraÃ¯Â¿Â½Ã¯Â¿Â½o de tempo.
  component IntegrationTimeController is
    port(
      Clock, NotReset, ReleaseFrame : in STD_LOGIC;
      FrameDone : out STD_LOGIC
      );
  end component;
  -- DigitalRegisterController : Controlador de registradores digitais do sensor.
  component DigitalRegisterController is 
    port(
      WIN, ITR, GC, IMRO, NDRO, RE, RST, OE_EN : in STD_LOGIC;
      PW, BW, OM : in STD_LOGIC_VECTOR( 1 downto 0 ); 
      I, AP, RO : in STD_LOGIC_VECTOR( 2 downto 0 );
      TS : in STD_LOGIC_VECTOR( 7 downto 0 );
      WAX, WSX : in STD_LOGIC_VECTOR( 7 downto 0 );
      WAY, WSY : in STD_LOGIC_VECTOR( 6 downto 0 );
      Clock, nReset, FSYNC, SetConfiguration : in STD_LOGIC;
          SerialData, Busy : out STD_LOGIC;
          Debug : out STD_LOGIC_VECTOR( 1 downto 0 )
    );
  end component;
  -- ChangeDetector : controlador que verifica se houve alteraÃ¯Â¿Â½Ã¯Â¿Â½o em algumas das entradas para
  -- poder realizar a configuraÃ¯Â¿Â½Ã¯Â¿Â½o na dataSerial.
  component ChangeDetector is
    port(
      -- Entradas de IO para configuraÃ¯Â¿Â½Ã¯Â¿Â½o dos registradores.
      InputData : STD_LOGIC_VECTOR( 60 downto 0 );
  
      ControllerBusy, Clock, NotReset : in STD_LOGIC;
      SetConfiguration : out STD_LOGIC;

      Debug : out STD_LOGIC_VECTOR(1 downto 0)

    );
  end component;
  -- Componente que faz um prÃ¯Â¿Â½-processamento no dado de entrada.
  component DataPreProcess is
    port(
      nEnable : in STD_LOGIC;
      DataIn  : in STD_LOGIC_VECTOR( 7 downto 0 );
      DataOut : out STD_LOGIC_VECTOR( 7 downto 0 )
      );
  end component;

  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o do tipo do estado.
  type TYPE_STATE is ( state_waitFrame, state_lineSyncPulse, state_waitPixel, state_getRow, state_waitLineSyncPulse );
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o dos tipos usados para diferenciar os delays para LSYNC e de ROW.
  type TYPE_ROW_DELAY_MODE is ( ROW_DELAY_MODE_START, ROW_DELAY_MODE_END );
  type TYPE_LINE_SYNC_DELAY_MODE is ( LINE_SYNC_DELAY_MODE_START, LINE_SYNC_DELAY_MODE_END );
  
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de constantes
  --
  -- CLOCK_EDGE_TYPE: tipo de borda do clock. 1/0 => subida/descida
  constant CLOCK_EDGE_TYPE : STD_LOGIC := '0';
  -- CLOCK_EDGE_FSYNC : tipo de borda do clock para o FSYNC 1/0 => subida/descida
  constant CLOCK_EDGE_FSYNC : STD_LOGIC := '1';
  -- RESET_EVENT: valor que representa um reset.
  constant RESET_EVENT : STD_LOGIC := '0';
  -- FRAME_DONE: valo que representa que tem um frame pronto para ser processado.
  constant FRAME_DONE : STD_LOGIC := '1';
  -- FSYNC_ASSERT/DEASSERT: valor que representa a lÃ¯Â¿Â½gica de mostrar que inicia o processo
  -- de captura de um frame.
  constant FSYNC_ASSERT : STD_LOGIC := '1';
  constant FSYNC_DEASSERT : STD_LOGIC := '0';
  -- LSYNC_ASSERT/DEASSERT: valor que representa a lÃ¯Â¿Â½gica de gerar um pulso para o LSYNC.
  constant LSYNC_ASSERT : STD_LOGIC := '1';
  constant LSYNC_DEASSERT : STD_LOGIC := '0';
  -- WRITE_MEM_ASSERT/DEASSERT: representaÃ¯Â¿Â½Ã¯Â¿Â½o para o nÃ¯Â¿Â½vel lÃ¯Â¿Â½gico para escrever e nÃ¯Â¿Â½o escrever respectivamente.
  constant WRITE_MEM_ASSERT : STD_LOGIC := '1';
  constant WRITE_MEM_DEASSERT : STD_LOGIC := '0';
  -- Constantes de configuraÃ¯Â¿Â½Ã¯Â¿Â½o do sensor.
  -- PIXEL_PER_ROW: nÃ¯Â¿Â½mero de pixels presente em uma linha.
  -- MAX_ROW_COUNTER: nÃ¯Â¿Â½mero de linhas que tem no sensor.
  -- NUMBER_TEST_ROW : constante que define o nÃ¯Â¿Â½mero de linhas de testes enviada pelo sensor. Durante estas linhas
  --                   vai ignorar (nÃ¯Â¿Â½o vai ser escrita na memÃ¯Â¿Â½ria ).
  -- PIXEL_TIME_ARRIVE: o tempo de chegada do primeiro pixel depois de ter dado um pulso de LSYNC.
  --                    Este tempo Ã¯Â¿Â½ dado em mÃ¯Â¿Â½ltiplos de um periodo correspondente ao clock do
  --                    sensor (ex.: Clock sensor = 5MHz entÃ¯Â¿Â½o 10us precisa definir 50 ).
  -- PIXEL_TIME_END_DELAY: tempo de delay dado no final do Ã¯Â¿Â½ltimo pixel, logo antes de dar um pulso de LSYNC.
  -- LINE_SYNC_PULSE_TIME: delay que deve ser dado apÃ¯Â¿Â½s asserÃ¯Â¿Â½Ã¯Â¿Â½o do FSYNC e antes de sua DEASSERCAO com
  --                       relaÃ¯Â¿Â½Ã¯Â¿Â½o ao pulso de LSYNC.
  constant PIXEL_PER_ROW : INTEGER := 320;
  constant MAX_ROW_COUNTER : INTEGER := 258;
  constant NUMBER_TEST_ROW : INTEGER range 0 to 2 := 2;
  constant PIXEL_TIME_ARRIVE : INTEGER := 2;
  constant PIXEL_TIME_END_DELAY : INTEGER := 13;--32;--13;
  constant LINE_SYNC_PULSE_TIME : INTEGER := 1;
  -- RELEASE_FRAME: flag que indica que pode liberar o frame. Ã¯Â¿Â½til para o tempo de integraÃ¯Â¿Â½Ã¯Â¿Â½o.
  constant RELEASE_FRAME : STD_LOGIC := '1';
  constant NOT_RELEASE_FRAME : STD_LOGIC := not RELEASE_FRAME;
  -- SELECT_OUTA/B/C/D : constantes que selecionam as saÃ¯Â¿Â½das OUTA, OUTB, OUTC ou OUTD do sensor.
  constant SELECT_OUTA : STD_LOGIC_VECTOR( 3 downto 0 ) := "0001";
  constant SELECT_OUTB : STD_LOGIC_VECTOR( 3 downto 0 ) := "0010";
  constant SELECT_OUTC : STD_LOGIC_VECTOR( 3 downto 0 ) := "0100";
  constant SELECT_OUTD : STD_LOGIC_VECTOR( 3 downto 0 ) := "1000";
  -- DATA_CODE_MODE_DEFAULT : constante que deixa o dada code mode em modo de operaÃ¯Â¿Â½Ã¯Â¿Â½o default.
  constant DATA_CODE_MODE_DEFAULT : STD_LOGIC := '0';
  -- NO_CHANGES_INPUT : constante que indica que nÃ¯Â¿Â½o houve alteraÃ¯Â¿Â½Ã¯Â¿Â½o nas entradas.
  constant NO_CHANGES_INPUT : STD_LOGIC := '0';
  constant UPDATING_INPUT : STD_LOGIC := '0';
  constant INPUT_UPDATED : STD_LOGIC := '1';
  constant WAITING_CONTROLLER : STD_LOGIC := '1';
  -- DISABLE_PRE_PROCESS : constante de ativaÃ¯Â¿Â½Ã¯Â¿Â½o/desativaÃ¯Â¿Â½Ã¯Â¿Â½o do pre-processamento de dado.
  constant DISABLE_PRE_PROCESS : STD_LOGIC := '0';
  -- ENABLE/DISABLE_DIGITAL_CONTROLLER : sianis de ativaÃ¯Â¿Â½Ã¯Â¿Â½o ou desativaÃ¯Â¿Â½Ã¯Â¿Â½o do controlador digital.
  constant DISABLE_DIGITAL_CONTROLLER : STD_LOGIC := '0';
  constant ENABLE_DIGITAL_CONTROLLER  : STD_LOGIC := '1';
  -- INITIAL_FRAME_COUNT : quantidade de frames que deve dar no inicio para ativar
  --                       o mÃ¯Â¿Â½dulo de controle digital.
  constant INITIAL_FRAME_COUNT : INTEGER range 0 to 5 := 5;

  -- Constantes internas nÃ¯Â¿Â½o parametrizaveis.
  --
  -- CLOCK_CYCLES_ROW: definiÃ¯Â¿Â½Ã¯Â¿Â½o do nÃ¯Â¿Â½mero de ciclos de clock (principal) deverÃ¯Â¿Â½ esperar para pegar
  -- todos os pixels. Este valor Ã¯Â¿Â½ a metade do nÃ¯Â¿Â½mero de pixels em uma linha jÃ¯Â¿Â½ que ele libera 1 pixel
  -- a cada metade ciclo de clock. Esta relaÃ¯Â¿Â½Ã¯Â¿Â½o tem que ser equivalente no valor da frequencia do
  -- pixel clock.
  constant CLOCK_CYCLES_ROW : INTEGER := PIXEL_PER_ROW/2;
  
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de constantes de inicializaÃ¯Â¿Â½Ã¯Â¿Â½o.
  --
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o da inicializaÃ¯Â¿Â½Ã¯Â¿Â½o dos sincronismos.
  constant INITIAL_FSYNC, INITIAL_LSYNC : STD_LOGIC := '0';

  --signal RST_Sensor : STD_LOGIC := '0';
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de sinais.
  signal lFSYNC, lLSYNC : STD_LOGIC;
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o do sinal de controle do estado.
  signal state : TYPE_STATE;
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de contadores.
  signal rowCounter, pixelCounter, timeCounter : INTEGER;
  -- DefiniÃ¯Â¿Â½Ã¯Â¿Â½o de sinais de flags.
  signal rowDelayMode : TYPE_ROW_DELAY_MODE;
  signal lineSyncDelayMode : TYPE_LINE_SYNC_DELAY_MODE;
  signal lFrameDone, lReleaseFrame : STD_LOGIC;
  -- Sinal de indicaÃ¯Â¿Â½Ã¯Â¿Â½o que o controlador de registradores digitais estÃ¯Â¿Â½ ocupado.
  signal lDigitalControllerBusy, lSetConfiguration : STD_LOGIC;

  signal lDebug : STD_LOGIC_VECTOR( 1 downto 0 );

  signal lInput : STD_LOGIC_VECTOR( 60 downto 0 );

  signal digitalEnable, EnableDigitalController : STD_LOGIC;

  signal initialFSYNCCounter : INTEGER range 0 to INITIAL_FRAME_COUNT;

  --signal Clock : STD_LOGIC;
  signal PixelClcok : STD_LOGIC;

  signal DataIn_1 : STD_LOGIC_VECTOR(7 downto 0);
  signal DataIn_2 : STD_LOGIC_VECTOR(7 downto 0);
  signal WriteMem_1 : STD_LOGIC;
  signal WriteMem_d1 : STD_LOGIC;
  signal Pixel_Clock_delayed_1 : STD_LOGIC;
  signal Pixel_Clock_delayed : STD_LOGIC;


  -- VALORES INICIAIS DOS REGISTRADORES INTERNOS
    signal WIN, ITR, GC, IMRO, NDRO, RE, RST:  STD_LOGIC := '0';
    --signal PW : STD_LOGIC_VECTOR(1 downto 0):= "10";
--  signal OM :  STD_LOGIC_VECTOR( 1 downto 0 ) := "00";
--  signal BW :  STD_LOGIC_VECTOR( 1 downto 0 ) := "00"; 
    --signal I, AP : STD_LOGIC_VECTOR (2 downto 0) := "100"; --default: "100";
    signal RO :  STD_LOGIC_VECTOR( 2 downto 0 ) := "000";
    signal TS :  STD_LOGIC_VECTOR( 7 downto 0 ) := (others => '0');
    signal WAX :  STD_LOGIC_VECTOR( 7 downto 0 ) :=  (others => '0');
    signal WSX :  STD_LOGIC_VECTOR( 7 downto 0 ) :=  (others => '0');
    signal WAY :  STD_LOGIC_VECTOR( 6 downto 0 ) :=  (others => '1');
    signal WSY :  STD_LOGIC_VECTOR( 6 downto 0 ) :=  (others => '1');
   
  
begin

  --REGISTRADOR PARA JANELAMENTO
  --WIN <= swir_registers(30);
  --REGISTRADORES PARA WIN = 0
  --ITR   <= swir_registers(29);
  --GC    <= swir_registers(28);
  --PW    <= swir_registers(27 downto 26);
  --I     <= swir_registers(25 downto 23);
  --AP    <= swir_registers(22 downto 20);
  --BW    <= swir_registers(19 downto 18);
  --IMRO  <= swir_registers(17);
  --NDRO  <= swir_registers(16);
  --TS    <= swir_registers(15 downto 8);
  --RO    <= swir_registers(7 downto 5);
  --OM    <= swir_registers(4 downto 3);
  --RE    <= swir_registers(2);
  --RST   <= swir_registers(1);
  --OE_EN <= swir_registers(0);
  
  --REGISTRADORES PARA WIN = 1
  --WAX   <= swir_registers(29 downto 22);
  --WAY   <= swir_registers(21 downto 15);
  --WSX   <= swir_registers(14 downto 7);
  --WSY   <= swir_registers(6 downto 0);

   flop_data_process: process (Pixel_Clock, NotReset) is
  begin  -- process flop_data_process
    if NotReset = '0' then              -- asynchronous reset (active low)
      DataIn_1 <= (others => '0');
      DataIn_2 <= (others => '0');
      Pixel_Clock_delayed_1 <= '0';
      Pixel_Clock_delayed <= '0';
    elsif Pixel_Clock'event and Pixel_Clock = '1' then  -- rising clock edge
      DataIn_1 <= DataIn;
      DataIn_2 <= DataIn_1;
      WriteMem <= WriteMem_1;
    end if;
  end process flop_data_process;

  
  --PrescalerSensorInterface_1: entity work.PrescalerSensorInterface
  --  port map (
  --    ClockIn    => Master_Clock,
  --    NotReset   => NotReset,
  --    ClockOut   => Clock,
  --    PixelClock => PixelClcok);

  --PrescalerADClock_1: entity work.PrescalerADClock
  --  port map (
  --    ClockIn  => Master_Clock,
  --    NotReset => NotReset,
  --    ClockOut => AD_Clock);
  
  -- LigaÃ¯Â¿Â½Ã¯Â¿Â½o lÃ¯Â¿Â½gica para o prÃ¯Â¿Â½-processador de imagem.
  PRE_PROCESS_IMAGE : DataPreProcess port map(
    nEnable => nInvertPattern, DataIn => DataIn_2, DataOut => DataOut
    );

  -- LigaÃ¯Â¿Â½Ã¯Â¿Â½o lÃ¯Â¿Â½gica para o change Detector.
  CHANGE_DETECOTR : ChangeDetector port map(

                      InputData => lInput, ControllerBusy => lDigitalControllerBusy,
                      Clock => Sensor_Clock, NotReset => NotReset,
                      SetConfiguration => lSetConfiguration, Debug => open
                    );

  -- LigaÃ¯Â¿Â½Ã¯Â¿Â½o lÃ¯Â¿Â½gica de componentes.
  INTEGRATION_TIME : IntegrationTimeController port map(
    Clock => Sensor_Clock, NotReset => NotReset, ReleaseFrame => lReleaseFrame,
    FrameDone => lFrameDone 
    );

  -- LigaÃ¯Â¿Â½Ã¯Â¿Â½o lÃ¯Â¿Â½gica do Controlador Digital.
  DIGITAL_REGISTER_CONTROLLER : DigitalRegisterController port map(
                                  WIN => WIN, ITR => ITR, GC => GC, IMRO => IMRO, NDRO => NDRO,
                                  RE => RE , RST => RST, OE_EN => OE_EN, PW => PW, BW => BW,
--RE ALTERADO PARA TESTES!
                                  OM => OM, I => I, AP => AP, RO => RO, TS => TS, WAX => WAX,
                                  WSX => WSX, WAY => WAY, WSY => WSY,
                                  Clock => Sensor_Clock, nReset => EnableDigitalController, FSYNC => lFSYNC,
                                  SetConfiguration => lSetConfiguration, SerialData => DataCodeMode,--DataCodeMode,
                                  Busy => lDigitalControllerBusy, Debug => open
                                );

  -- MantÃ¯Â¿Â½m o controlador digital resetado atÃ¯Â¿Â½ que tenha ativado o processo.
  EnableDigitalController <= ENABLE_DIGITAL_CONTROLLER when( NotReset /= RESET_EVENT and digitalEnable = ENABLE_DIGITAL_CONTROLLER ) else
                             DISABLE_DIGITAL_CONTROLLER;

  -- SÃ¯Â¿Â½ ativa o digital controller quando jÃ¯Â¿Â½ tiver passado a quantidade de frames necessÃ¯Â¿Â½rias.
  digitalEnable <= ENABLE_DIGITAL_CONTROLLER when( initialFSYNCCounter = INITIAL_FRAME_COUNT ) else
                   DISABLE_DIGITAL_CONTROLLER;

  -- Libera o frame sempre que tiver no estado de espera de frame.
  lReleaseFrame <= RELEASE_FRAME when( state = state_waitFrame ) else
                   NOT_RELEASE_FRAME;

  -- Configura a saÃ¯Â¿Â½da selecionada como sendo o OUTA (como versÃ¯Â¿Â½o de teste).
  OutSelection <= SELECT_OUTA;

  -- LigaÃ¯Â¿Â½Ã¯Â¿Â½o lÃ¯Â¿Â½gicas de elementos.
  FSYNC <= lFSYNC;
  LSYNC <= lLSYNC;
  --DataCodeMode <= '0';
  --Pixel_Clock <= PixelClcok;
  --Sensor_Clock <= Clock;
  EOF <= lFrameDone;
  -- A ativaÃ¯Â¿Â½Ã¯Â¿Â½o de escrita na memÃ¯Â¿Â½ria pode ser vista como o inverso do FSYNC (sincronismo de frame).
  --StartWriteMem <= not lFSYNC;
  
  -- O WriteClock usado na interface da memÃ¯Â¿Â½ria Ã¯Â¿Â½ pode ser usado como o sinal de clock gerado para o pixel.
  -- Pixel clock tem uma frequencia igual ao dobro do Clock principal.
  --WriteClock <= PixelClcok;
  
  -- Gera um pulso no LSYNC sempre que estiver no estado correspondente.
  lLSYNC <= LSYNC_ASSERT when( state = state_lineSyncPulse ) else
            LSYNC_DEASSERT;
  
  -- Gera um pulso para a escrita na memÃ¯Â¿Â½ria.
  

  -- Proecesso que faz a contagem de frames de inicializaÃ¯Â¿Â½Ã¯Â¿Â½o.
  FSM_INITIAL_FRAME_COUNTER : process( lFSYNC, NotReset )
  begin
    if( NotReset = RESET_EVENT ) then
      initialFSYNCCounter <= 0;
    elsif( lFSYNC = CLOCK_EDGE_TYPE and lFSYNC'event ) then

      -- Faz a contagem dos "INITIAL_FRAME_COUNT" primeiros frame sync e para de incrementar.
      if( initialFSYNCCounter /= INITIAL_FRAME_COUNT ) then
        initialFSYNCCounter <= initialFSYNCCounter + 1;
      end if;  

    end if;
    
  end process;

  FSM_INTERFACE : process( Sensor_Clock, NotReset ) is
  begin
    -- Reset assincrono. Coloca as saÃ¯Â¿Â½das em nÃ¯Â¿Â½vel de inicializaÃ¯Â¿Â½Ã¯Â¿Â½o.
    if( NotReset = RESET_EVENT ) then
      rowCounter <= 0;
      timeCounter <= 0;
    -- Tratamento da mÃ¯Â¿Â½quina de estados.
    elsif( Sensor_Clock'event and Sensor_Clock = CLOCK_EDGE_TYPE ) then
      case( state ) is
        -- Espera por um frame estiver pronto para ser processado. Quando estiver
        -- asserta o bit que faz o sincronismo do frame para coletar o frame.
        when state_waitFrame =>
      if( lFrameDone = FRAME_DONE ) then
        state <= state_waitLineSyncPulse;
      else
        state <= state_waitFrame;
      end if;
      -- Inicializa o contador de tempo para o lSync e o modo do delay.
      timeCounter <= 0;
      lineSyncDelayMode <= LINE_SYNC_DELAY_MODE_START;
      
      -- Estado que espera o tempo necessÃ¯Â¿Â½rio para poder ir para o pulso de LSYNC ou sair
      -- Dele.
      when state_waitLineSyncPulse =>
      if( timeCounter = LINE_SYNC_PULSE_TIME-1 ) then
        -- Quando passar o tempo de sincronismo verifica qual tipo de delay foi feito
        -- o de LSYNC de inicio ou final. Se for final volta para o espera frame.
        if( lineSyncDelayMode = LINE_SYNC_DELAY_MODE_START ) then
          state <= state_lineSyncPulse;
        else
          state <= state_waitFrame;
        end if;
      -- Incrementa o tempo.
      else
        timeCounter <= timeCounter + 1;
        state <= state_waitLineSyncPulse;
      end if;
      -- Inicializa o contador de linhas.
      rowCounter <= 0;
      
      -- Estado que envia um pulso de syncronismo para indicar transmissÃ¯Â¿Â½o de uma linha.
      -- Faz o teste para verificar se finalizou a recpÃ¯Â¿Â½Ã¯Â¿Â½o de todas as linhas atraveis de um
      -- contador. Quando chegar ao fim, volta ao inicio do frame.
      when state_lineSyncPulse =>
      -- Verifica o limite do contador. Quando acabar as linhas vai para o estado que espera o tempo
      -- para indicar final
      if( rowCounter = MAX_ROW_COUNTER ) then
        state <= state_waitLineSyncPulse;
        lineSyncDelayMode <= LINE_SYNC_DELAY_MODE_END;
      else
        state <= state_waitPixel;
        rowCounter <= rowCounter + 1;
      end if;
      -- Inicializa o contador para o contador de pixel.
      timeCounter <= 0;
      rowDelayMode <= ROW_DELAY_MODE_START;
      
      -- Estado que espera um tempo determinado para poder ter pixel pronto a ser transmitido.
      when state_waitPixel =>
      -- Se for no modo de inicio, espera o tempo necessÃ¯Â¿Â½rio para o primeiro pixel chegar.
      if( rowDelayMode = ROW_DELAY_MODE_START ) then
        if( timeCounter = PIXEL_TIME_ARRIVE-1 ) then
          state <= state_getRow;
        else
          timeCounter <= timeCounter + 1;
          state <= state_waitPixel;
        end if;
      -- Se for no modo de final, espera o tempo necessÃ¯Â¿Â½rio dado no antes de dar mais um pulso de
      -- LSYBNC.
      else
        if( timeCounter = PIXEL_TIME_END_DELAY-1 ) then
          state <= state_lineSyncPulse;
        else
          state <= state_waitPixel;
          timeCounter <= timeCounter + 1;
        end if;
      end if;
      -- Inicializa o contador de pixel de cada linha.
      pixelCounter <= 0;
      
      
      -- Estado que pega todos os pixels de uma linha. SÃ¯Â¿Â½ sai deste estado quando
      -- capturar todos os pixels. Espera o nÃ¯Â¿Â½mero de ciclos necessÃ¯Â¿Â½rio para pegar todos
      -- os pixels de uma linha.
      when state_getRow =>
      if( pixelCounter = CLOCK_CYCLES_ROW-1 ) then
        state <= state_waitPixel;
        -- Inicializa o contador de tempo de pixel para o tempo necessÃ¯Â¿Â½rio no final da linha.
        timeCounter <= 0;
        rowDelayMode <= ROW_DELAY_MODE_END;
      else
        pixelCounter <= pixelCounter + 1;
        state <= state_getRow;
      end if;
    end case;
      
    end if;
  end process;
  
  -- Processo que gera o sinal para o FSYNC baseado em um clock de borda de subida.
  FSM_FSYNC_GENERATOR : process( Sensor_Clock, NotReset ) is
  begin
    if( NotReset = RESET_EVENT ) then
      lFSYNC <= FSYNC_DEASSERT;
    elsif( Sensor_Clock'event and Sensor_Clock = CLOCK_EDGE_FSYNC ) then
      -- Asserta o lFSYNC sempre que nÃ¯Â¿Â½o estiver esperando um novo Frame.
      if( state /= state_waitFrame ) then
        lFSYNC <= FSYNC_ASSERT;
      else
        lFSYNC <= FSYNC_DEASSERT;
      end if;
    end if;
  end process;


  write_mem_process: process (Pixel_Clock, NotReset, state) is
  begin  -- process write_mem_process
    if NotReset = '0' then              -- asynchronous reset (active low)
      WriteMem_1 <= '0';
    elsif Pixel_Clock'event and Pixel_Clock = '1' then  -- rising clock edge
      -- SINAL PARA ESCRITA NA MEMORIA
      if ( state = state_getRow and rowCounter > NUMBER_TEST_ROW ) then
         WriteMem_1 <= WRITE_MEM_ASSERT;
      else
        WriteMem_1 <= WRITE_MEM_DEASSERT;
      end if;
    end if;
  end process write_mem_process;

 

  -- Concatena a entrada para enviar ao mÃ¯Â¿Â½dulo de detecÃ¯Â¿Â½Ã¯Â¿Â½o de mudanÃ¯Â¿Â½a.
  lInput <= WIN & ITR & GC & IMRO & NDRO & RE & RST_Sensor & OE_EN & PW & BW & OM & 
            I & AP & RO & TS & WAX & WSX & WAY & WSY;
  -- DepuraÃ¯Â¿Â½Ã¯Â¿Â½o. Comentar na versÃ¯Â¿Â½o final.
  --debugState <= std_logic_vector( TYPE_STATE'pos(state), 3);

  --debugState <= lSetConfiguration & lDigitalControllerBusy & ;

end FSM_SensorInterface;
