-- Sound board used on Williams System 3 and System 4 pinball machines. There seems to be only one ROM image used in all of these games. 
-- (c)2015 James Sweet
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.

library ieee;
use ieee.std_logic_1164.all;


entity System4_snd is
port(
		DAC_CLK		: in std_logic; -- High speed clock for the audio DAC, 30-100 MHz works well
		CPU_CLK		: in std_logic; -- 3.58 MHz CPU clock
		RESET_L		: in std_logic; -- Reset input, active low
		SND_CTL_I	: in std_logic_vector(7 downto 0); -- Sound control inputs
		AUDIO_O		: out std_logic -- PWM audio signal from Delta-Sigma DAC
);
end System4_snd;


architecture rtl of System4_snd is

signal diag_sw		: std_logic := '0'; -- Diagnostic switch, this can be brought out to a pin if desired

signal reset_h		: std_logic;

signal audio		: std_logic_vector(7 downto 0);

signal cpu_addr	: std_logic_vector(15 downto 0);
signal cpu_din		: std_logic_vector(7 downto 0);
signal cpu_dout	: std_logic_vector(7 downto 0);
signal cpu_rw		: std_logic;
signal cpu_vma		: std_logic;
signal cpu_irq		: std_logic;
signal cpu_nmi		: std_logic;

signal rom_dout	: std_logic_vector(7 downto 0);
signal rom_cs		: std_logic;

signal ram_dout	: std_logic_vector(7 downto 0);
signal ram_cs		: std_logic;
signal ram_we		: std_logic;

signal pia_dout	: std_logic_vector(7 downto 0);
signal pia_cs		: std_logic;
signal pia_irq_a	: std_logic := '1';
signal pia_irq_b	: std_logic := '1';
signal pia_cb1		: std_logic;

begin
reset_h <= (not reset_l);
cpu_nmi <= diag_sw;

-- Real hardware uses a 6802 which is a 6800 with internal oscillator and 128 byte RAM
CPU: entity work.cpu68
port map(
	clk => cpu_clk,
	rst => reset_h,
	rw => cpu_rw,
	vma => cpu_vma,
	address => cpu_addr,
	data_in => cpu_din,
	data_out => cpu_dout,
	hold => '0',
	halt => '0',
	irq => cpu_irq,
	nmi => cpu_nmi
);

-- 6802 contains internal 128 byte RAM, using 6800 softcore so RAM is separate
RAM: entity work.mpu_ram
port map(
	address => cpu_addr(6 downto 0),
	clock => cpu_clk,
	data => cpu_dout,
	wren => not cpu_rw,
	q => ram_dout
	);

-- PIA IRQ outputs both assert CPU IRQ input
cpu_irq <= pia_irq_a or pia_irq_b;

-- Address decoding 
pia_cs <= cpu_addr(10) and (not cpu_addr(11)) and cpu_vma;
rom_cs <= cpu_addr(11) and cpu_vma;
ram_cs <= (not cpu_addr(7)) and cpu_vma;

-- Bus control
cpu_din <= 
	pia_dout when pia_cs = '1' else
	rom_dout when rom_cs = '1' else
	ram_dout when ram_cs = '1' else
	x"FF";

-- Real hardware uses 6820 Peripheral Interface Adapter, 6821 is functionally equivalent
PIA: entity work.pia6821
port map(
	clk => cpu_clk,   
   rst => reset_h,     
   cs => pia_cs,     
   rw => cpu_rw,    
   addr => cpu_addr(1 downto 0),     
   data_in => cpu_dout,  
	data_out => pia_dout, 
	irqa => pia_irq_a,   
	irqb => pia_irq_b,    
	pa_i => x"FF",    
	pa_o => audio,    
	ca1 => '1',    
	ca2_i => '1',    
	ca2_o => open,    
	pb_i => snd_ctl_i,    
	pb_o => open,    
	cb1 => pia_cb1,    
	cb2_i => '0',  
	cb2_o => open   
);

-- Sound control inputs all assert cb1 on PIA
pia_cb1 <= not (snd_ctl_i(7) and snd_ctl_i(5) and snd_ctl_i(4) and snd_ctl_i(3) and snd_ctl_i(2) and snd_ctl_i(1));

-- 2k ROM 
ROM: entity work.audio_rom
port map(
	address => cpu_addr(10 downto 0),
	clock	=> cpu_clk,
	q => rom_dout
	);

-- Delta Sigma DAC
Audio_DAC: entity work.dac
port map(
   clk_i   	=> dac_clk,
   res_n_i 	=> reset_l,
   dac_i   	=> audio,
   dac_o   	=> audio_o
	);

end rtl;
		