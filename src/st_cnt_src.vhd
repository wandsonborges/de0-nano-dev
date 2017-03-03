-------------------------------------------------------------------------------
-- Title      : st_cnt_src
-- Project    : 
-------------------------------------------------------------------------------
--
--     o  0                          
--     | /       Copyright (c) 2013
--    (CL)---o   Critical Link, LLC  
--      \                            
--       O                           
--
-- File       : st_cnt_src.vhd
-- Company    : Critical Link, LLC
-- Created    : 2013-12-1
-- Last update: 2013-12-5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Outputs a packetized count pattern
-------------------------------------------------------------------------------
-- Copyright (c) 2013 Critical Link, LLC
-------------------------------------------------------------------------------
-- Revisions  :
-- Date			Version	Author	Description
-- 2013-12-5	0.1		Dan V	Initial
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity st_cnt_src is
	generic (
		PKT_SIZE : integer                       := 0
	);
	port (
		clk            : in  std_logic                     := '0'; -- clock.clk
		reset          : in  std_logic                     := '0'; -- reset.reset
		aso_out0_data  : out std_logic_vector(63 downto 0);        --  out0.data
		aso_out0_ready : in  std_logic                     := '0'; --      .ready
		aso_out0_valid : out std_logic;                            --      .valid
		aso_out0_sop   : out std_logic;                            --      .startofpacket
		aso_out0_eop   : out std_logic                             --      .endofpacket
	);
end entity st_cnt_src;

architecture rtl of st_cnt_src is
signal s_pkt_cnt : unsigned(63 downto 0) := (others=>'0');
signal s_data_out : std_logic_vector(63 downto 0) := (others=>'0');
begin


	-- Avalon Streams are network bit order
	aso_out0_data(63 downto 56) <= s_data_out(39 downto 32);
	aso_out0_data(55 downto 48) <= s_data_out(47 downto 40);
	aso_out0_data(47 downto 40) <= s_data_out(55 downto 48);
	aso_out0_data(39 downto 32) <= s_data_out(63 downto 56);

	aso_out0_data(31 downto 24) <= s_data_out(7 downto 0);
	aso_out0_data(23 downto 16) <= s_data_out(15 downto 8);
	aso_out0_data(15 downto 8) <= s_data_out(23 downto 16);
	aso_out0_data(7 downto 0) <= s_data_out(31 downto 24);



	proc_output : process(clk, reset)
	begin
		if reset = '1' then
			s_pkt_cnt <= (others=>'0');
			aso_out0_valid <= '0';
			s_data_out <= X"DEADBEEFDEADBEEF";
		elsif rising_edge(clk) then
			if aso_out0_ready = '1' then
				aso_out0_sop <= '0';
				aso_out0_eop <= '0';
				s_data_out <= std_logic_vector(s_pkt_cnt);
				aso_out0_valid <= '1';

				if s_pkt_cnt = 0 then
					aso_out0_sop <= '1';
				end if;

				if s_pkt_cnt = PKT_SIZE then
					aso_out0_eop <= '1';
					s_pkt_cnt <= (others=>'0');
				else
					s_pkt_cnt <= s_pkt_cnt + 1;
				end if;
			end if;
		end if;
	end process proc_output;


end architecture rtl; -- of st_cnt_src
