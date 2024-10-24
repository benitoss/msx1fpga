--
-- RegisterMemory.vhd
--
-- Copyright (c) 2006 Mitsutaka Okazaki (brezza@pokipoki.org)
-- All rights reserved.
--
-- Redistribution and use of this source code or any derivative works, are
-- permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Redistributions may not be sold, nor may they be used in a commercial
--    product or activity without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
-- OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
-- OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--

--
--  modified by t.hara
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity RegisterMemory is
	port (
		clk     : in    std_logic;
		reset   : in    std_logic;
		addr    : in    std_logic_vector(  3 downto 0 );
		wr      : in    std_logic;
		idata   : in    std_logic_vector( 23 downto 0 );
		odata   : out   std_logic_vector( 23 downto 0 )
	);
end entity;

architecture rtl of registermemory is
	--  チャネル情報保持用 1read/1write の SRAM
	type regs_array_type is array (0 to 8) of std_logic_vector( 23 downto 0 );
	signal regs_array			: regs_array_type;
	signal mem_wr_s			: std_logic;
	signal mem_addr_s			: integer;
	signal mem_data_s			: std_logic_vector( 23 downto 0 );
	signal init_state			: integer range 0 to 9;
	attribute ram_style		: string;
	attribute ram_style of regs_array : signal is "block";

begin

	mem_addr_s	<= init_state			when init_state /= 9	else conv_integer(addr);
	mem_data_s	<= (others => '0')	when init_state /= 9	else idata;
	mem_wr_s		<= '1'					when init_state /= 9	else wr;

	process (reset, clk)
	begin
		if reset = '1' then
			init_state <= 0;
		elsif clk'event and clk ='1' then
			if mem_wr_s = '1' then
				--  書き込みサイクル
				regs_array( mem_addr_s ) <= mem_data_s;
			end if;
			--  読み出しは常時
			odata <= regs_array( conv_integer(addr) );
			if init_state /= 9 then
				--  起動してすぐに RAM の内容を初期化する
				init_state <= init_state + 1;
				end if;
		end if;
	end process;
end architecture;
