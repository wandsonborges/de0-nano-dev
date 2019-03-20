-------------------------------------------------------------------------------
-- Title      : Synchronizer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : dualFfSynchronizer.vhd
-- Author     :   <Sistemas Embarcados@FERMI>
-- Company    : 
-- Created    : 2014-06-16
-- Last update: 2017-10-18
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Dual FF synchronizer
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-06-16  1.0      Sistemas Embarcados     Created
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Lbirary includes.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
-- Interface
-------------------------------------------------------------------------------
entity dFfVectorSynchronizer is
  generic (
    -- User may select the number of synchronization stages.
    SYNCHRONIZATION_STAGES : INTEGER := 2;
    REGISTER_WIDTH         : INTEGER := 8
    );
  port (
    clock  : in  STD_LOGIC;
    nReset : in  STD_LOGIC;
    input  : in  STD_LOGIC_VECTOR(REGISTER_WIDTH-1 downto 0);
    output : out STD_LOGIC_VECTOR(REGISTER_WIDTH-1 downto 0)
    );
end dFfVectorSynchronizer;

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
architecture behavior of dFfVectorSynchronizer is

  type TYPE_SYNCHRONIZATION_REGISTER is array (0 to SYNCHRONIZATION_STAGES-1) of STD_LOGIC_VECTOR(REGISTER_WIDTH-1 downto 0);
  
  signal synchronizationFf : TYPE_SYNCHRONIZATION_REGISTER;
  
begin  -- behavior

  -----------------------------------------------------------------------------
  -- Synchronization
  -----------------------------------------------------------------------------
  SYNCHRONIZATION : process (clock, nReset)
  begin  -- process SYNCHRONIZATION
    if nReset = '0' then
      synchronizationFf <= (others => (others => '0'));
    elsif clock'event and clock = '1' then  -- rising clock edge
      synchronizationFf(0) <= input;
      for i in 1 to SYNCHRONIZATION_STAGES-1 loop
        synchronizationFf(i) <= synchronizationFf(i-1);
      end loop;  -- i
    end if;
  end process SYNCHRONIZATION;
  output <= synchronizationFf(SYNCHRONIZATION_STAGES-1);

end behavior;
