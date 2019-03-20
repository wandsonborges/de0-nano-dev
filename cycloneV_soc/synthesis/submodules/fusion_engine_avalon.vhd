library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.uteis.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity fusion_engine_avalon is
  
  generic (
    NBITS_ADDR : integer := 32;
    NBITS_PACKETS : integer := 32;
    FIFO_SIZE : integer := 1024;
    FIFO_SIZE_BITS : integer := 10;
    NBITS_DATA : integer := 32;
    NBITS_BURST : integer := 4;
    NBITS_BYTEEN : integer := 4;
    BURST : integer := 8;
    ADDR_READ1 : std_logic_vector(31 downto 0) := x"38000000";
    ADDR_READ2 : std_logic_vector(31 downto 0) := x"38100000";
    ADDR_WRITE : std_logic_vector(31 downto 0) := x"38200000"
    );

  port (
    --clk and reset_n
    clk, rst_n : in std_logic;
  
    -- avalon MM Master 1 - Write Add Vector Result
    masterwr_waitrequest : in std_logic;
    masterwr_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterwr_write       : out std_logic;
    masterwr_writedata   : out std_logic_vector(NBITS_DATA-1 downto 0);
    

    -- avalon MM Master 2 - Get Header and Vector 1
    masterrd1_waitrequest : in std_logic;
    masterrd1_readdatavalid : in std_logic;
    masterrd1_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd1_burstcount   : out std_logic_vector(3 downto 0);
    masterrd1_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd1_read       : out std_logic;

    -- avalon MM Master 2 - Get Vector 2
    masterrd2_waitrequest : in std_logic;
    masterrd2_readdatavalid : in std_logic;
    masterrd2_readdata   : in std_logic_vector(NBITS_DATA-1 downto 0);
    masterrd2_burstcount   : out std_logic_vector(3 downto 0);
    masterrd2_address     : out std_logic_vector(NBITS_ADDR-1 downto 0);
    masterrd2_read       : out std_logic;
    
    -- avalon MM Slave - Configure addVector Hardware
    slave_chipselect    : in std_logic;
    slave_read          : in std_logic;
    slave_write         : in std_logic;
    slave_address       : in std_logic_vector(2 downto 0);
    slave_byteenable    : in std_logic_vector(NBITS_BYTEEN-1 downto 0);
    slave_writedata     : in std_logic_vector(31 downto 0);
    slave_waitrequest   : out std_logic;
    slave_readdatavalid : out std_logic;
    slave_readdata      : out std_logic_vector(31 downto 0)
    
    
    );               

end entity fusion_engine_avalon;

architecture bhv of fusion_engine_avalon is

  signal v1_masterrd_waitrequest   : std_logic;
  signal v1_masterrd_readdatavalid : std_logic;
  signal v1_masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v1_masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v1_masterrd_read          : std_logic;
  signal v1_enable_read            : std_logic;
  signal v1_packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal v1_address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v1_get_read_data          : std_logic;
  signal v1_data_ready             : std_logic;
  signal v1_data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v1_burst_en               : std_logic;
  signal v1_masterrd_burstcount    : std_logic_vector(3 downto 0);


  signal v2_masterrd_waitrequest   : std_logic;
  signal v2_masterrd_readdatavalid : std_logic;
  signal v2_masterrd_readdata      : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v2_masterrd_address       : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v2_masterrd_read          : std_logic;
  signal v2_enable_read            : std_logic;
  signal v2_packets_to_read        : std_logic_vector(NBITS_PACKETS-1 downto 0);
  signal v2_address_init           : std_logic_vector(NBITS_ADDR-1 downto 0);
  signal v2_get_read_data          : std_logic;
  signal v2_data_ready             : std_logic;
  signal v2_data_out               : std_logic_vector(NBITS_DATA-1 downto 0);
  signal v2_burst_en               : std_logic;
  signal v2_masterrd_burstcount    : std_logic_vector(3 downto 0);

  
  -- BUFFER ADDR:
  constant ADDR_BASE_READ : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_READ1;
  constant ADDR_BASE_READ2 : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_READ2;
  constant ADDR_BASE_WRITE : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_WRITE;

  -- FUSION ENGINE SIGNALS
  signal float_img_comeca         : std_logic;
  signal fixed_img_comeca         : std_logic;
  signal float_img_port_buffer_id : buffer_id_t;
  signal float_img_port_data      : word_mem_t;
  signal float_img_port_addr      : endr_mem_t;
  signal float_img_port_rd_en     : std_logic;
  signal float_img_port_addr_disp : std_logic;
  signal float_img_port_addr_req  : std_logic;
  signal float_img_port_burst_en  : std_logic;
  signal fixed_img_port_buffer_id : buffer_id_t;
  signal fixed_img_port_data      : word_mem_t;
  signal fixed_img_port_addr      : endr_mem_t;
  signal fixed_img_port_rd_en     : std_logic;
  signal fixed_img_port_addr_disp : std_logic;
  signal fixed_img_port_addr_req  : std_logic;
  signal fixed_img_port_burst_en  : std_logic;
  signal fusao_wr_port_buffer_id  : buffer_id_t;
  signal fusao_wr_port_data       : word_mem_t;
  signal fusao_wr_port_addr       : endr_mem_t;
  signal fusao_wr_port_wr_en      : std_logic;
  signal fusao_wr_port_addr_disp  : std_logic;
  signal fusao_wr_port_addr_req   : std_logic;
  signal fusao_wr_port_burst_en   : std_logic;
  signal brilho_offset            : std_logic_vector(7 downto 0);
  signal jtag_tipo_fusao          : std_logic_vector(1 downto 0);
  signal norma_threshold          : std_logic_vector(C_LARGURA_PIXEL+2-1 downto 0);
  signal matriz_homog_wr_data     : std_logic_vector(31 downto 0);
  signal matriz_homog_wr_en       : std_logic;
  signal clear                    : std_logic;
  signal end_frame                : std_logic;
  signal ent_valid                : std_logic;
  signal mi_valid                 : std_logic;
  signal ent_data                 : std_logic_vector(16 + 4 + 4 +4 + 1-1 downto 0);
  signal mi_data                  : std_logic_vector(16 + 4 + 4 +4 + 1-1 downto 0);
  signal escolhe_metodo_registro  : std_logic_vector(1 downto 0);
  signal enable_reg_lut           : std_logic_vector(0 downto 0);
  signal register_offset          : std_logic_vector(7 downto 0);
  signal escolhe_metodo_fusao     : std_logic_vector(1 downto 0);
  signal alpha                    : std_logic_vector(7 downto 0);
  signal pallete_select           : std_logic_vector(1 downto 0);
  signal threshold_thermal        : pixel_t;
  signal current_offset           : std_logic_vector(7 downto 0);
  signal current_alpha            : std_logic_vector(7 downto 0);
  signal current_threshold        : std_logic_vector(7 downto 0);


  --GENERAL SIGNALS
  signal wrcount : UNSIGNED(31 downto 0) := (others => '0');

  --CONTROL SIGNAL
  signal rdreq, start_op, start_op_f : std_logic := '0';

  signal vectorSize : std_logic_vector(31 downto 0);
  
  -- CONFIGURE ADD VECTOR HW SIGNALS
  type reg_type is array (0 to 6) of std_logic_vector(31 downto 0);
  constant init_registers : reg_type := (
    x"11223344", --id
    x"00005000", --vectorSize
    x"00000001", --start
    ADDR_BASE_READ, --addr vector 1
    ADDR_BASE_READ2, --addr vector 2
    ADDR_BASE_WRITE, -- addr vector result
    x"00000000" --busy
    );
  signal registers : reg_type := init_registers;

      -- AVALON SIGNALS
  signal s_address : std_logic_vector(NBITS_ADDR-1 downto 0) := ADDR_BASE_WRITE;
  signal s_masterwrite, s_masterread, s_masterread_f : std_logic := '0';

begin  -- architecture bhv

-- AVALON SLAVE: ADD VECTOR HW CONF
 rd_wr_slave_proc: process (clk, rst_n) is
  begin  -- process rd_wr_slave_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      slave_readdata <= (others => '0');
      slave_readdatavalid <= '0';
      registers <= init_registers;
    elsif clk'event and clk = '1' then  -- rising clock edge     
      --LEITURA DO SLAVE  ---- READ PROC
      if slave_read = '1' then
        slave_readdata <= registers(to_integer(unsigned(slave_address)));
        slave_readdatavalid <= '1';
      --ESCRITA NO SLAVE
      elsif slave_write = '1'  then
        if unsigned(slave_address) > 0 then 
          registers(to_integer(unsigned(slave_address))) <= slave_writedata;
          slave_readdatavalid <= '0';
        else
          slave_readdatavalid <= '0';  
        end if;        
      else
        slave_readdatavalid <= '0';
      end if;

      if wrcount > 0 then
        registers(6)(0) <= '1';
      else
        registers(6)(0) <= '0';
      end if;
      
    end if;
  end process rd_wr_slave_proc;

  vectorSize <= registers(1);
  start_op <= registers(2)(0);
  

  fusion_engine_ddr2_1: entity work.fusion_engine_ddr2
    generic map (
      NUMERO_COLUNAS           => 320,
      LARGURA_CONTADOR_COLUNAS => 9,
      NUMERO_LINHAS            => 256,
      LARGURA_CONTADOR_LINHAS  => 9,
      LARGURA_ITERACOES        => 4,
      NUMERO_ITERACOES         => 8,
      LARGURA_PASSO            => 1,
      LARGURA_BINS             => 16,
      LARGURA_ADDR_BINS        => 4,
      LARGURA_N_HISTOGRAMAS    => 2)
    port map (
      rst_n                    => rst_n,
      sys_clk                  => clk,
      mem_clk                  => clk,
      float_img_comeca         => '0',
      fixed_img_comeca         => '0',
      float_img_port_buffer_id => (others => '0'),
      float_img_port_data      => float_img_port_data, 
      float_img_port_addr      => float_img_port_addr,
      float_img_port_rd_en     => float_img_port_rd_en,
      float_img_port_addr_disp => float_img_port_addr_disp,
      float_img_port_addr_req  => float_img_port_addr_req,
      float_img_port_burst_en  => float_img_port_burst_en,
      fixed_img_port_buffer_id => fixed_img_port_buffer_id,
      fixed_img_port_data      => fixed_img_port_data,
      fixed_img_port_addr      => fixed_img_port_addr,
      fixed_img_port_rd_en     => fixed_img_port_rd_en,
      fixed_img_port_addr_disp => fixed_img_port_addr_disp,
      fixed_img_port_addr_req  => fixed_img_port_addr_req,
      fixed_img_port_burst_en  => fixed_img_port_burst_en,
      fusao_wr_port_buffer_id  => fusao_wr_port_buffer_id,
      fusao_wr_port_data       => fusao_wr_port_data,
      fusao_wr_port_addr       => fusao_wr_port_addr,
      fusao_wr_port_wr_en      => fusao_wr_port_wr_en,
      fusao_wr_port_addr_disp  => fusao_wr_port_addr_disp,
      fusao_wr_port_addr_req   => fusao_wr_port_addr_req,
      fusao_wr_port_burst_en   => fusao_wr_port_burst_en,
      brilho_offset            => brilho_offset,
      jtag_tipo_fusao          => jtag_tipo_fusao,
      norma_threshold          => norma_threshold,
      matriz_homog_wr_data     => matriz_homog_wr_data,
      matriz_homog_wr_en       => matriz_homog_wr_en,
      clear                    => clear,
      end_frame                => end_frame,
      ent_valid                => ent_valid,
      mi_valid                 => mi_valid,
      ent_data                 => ent_data,
      mi_data                  => mi_data,
      escolhe_metodo_registro  => escolhe_metodo_registro,
      enable_reg_lut           => enable_reg_lut,
      register_offset          => register_offset,
      escolhe_metodo_fusao     => escolhe_metodo_fusao,
      alpha                    => alpha,
      pallete_select           => pallete_select,
      threshold_thermal        => threshold_thermal,
      current_offset           => current_offset,
      current_alpha            => current_alpha,
      current_threshold        => current_threshold);


  register_offset(0) <= '0';
  escolhe_metodo_registro <= "01";
  escolhe_metodo_fusao <= "01";

  float_img_port_data <= masterrd1_readdata;
  masterrd1_address  <= float_img_port_addr;
  v1_masterrd_read   <= float_img_port_rd_en;
  --float_img_port_addr_disp <= not v1_masterrd_waitrequest;
  float_img_port_addr_req  <= v1_masterrd_read and not masterrd1_waitrequest; 
  float_img_port_burst_en  <= not masterrd1_waitrequest; 
  fixed_img_port_buffer_id <= (others => '0');

  masterrd1_read <= v1_masterrd_read;
  
  fixed_img_port_data      <= masterrd2_readdata; 
  masterrd2_address        <= fixed_img_port_addr;
  v2_masterrd_read         <= fixed_img_port_rd_en;
  --fixed_img_port_addr_disp <= v2_masterrd_read;
  fixed_img_port_addr_req  <= v2_masterrd_read and masterrd2_waitrequest; 
  fixed_img_port_burst_en  <= v2_masterrd_waitrequest; 
  fixed_img_port_buffer_id <= (others => '0');

  masterrd2_read <= v2_masterrd_read;

  --fusao_wr_port_buffer_id  <= (others => '0');
  masterwr_writedata       <= fusao_wr_port_data;
  masterwr_address         <= fusao_wr_port_addr;
  s_masterwrite            <= fusao_wr_port_wr_en; 
  --fusao_wr_port_addr_disp  <= fusao_wr_port_addr_disp;
  fusao_wr_port_addr_req   <= s_masterwrite and not masterwr_waitrequest;
  fusao_wr_port_burst_en   <= not masterwr_waitrequest;
      
  masterwr_write <= s_masterwrite;
  
 end bhv;
 
   
