-- Team Number (T-ZERO)
-- Dr. Abdallah S. Abdallah 
-- aua639@psu.edu
-- Register_4bits_PIPO_WithLoadOrShiftLeft.vhd
-- Version 1.0 , 10/19/2018

library IEEE;
use IEEE.std_logic_1164.all;

--	Rising-edge Clock
--	Active-high Synchronous Clear
--	Active-high Synchronous Enable


entity PIPO_Shift_Left is
	port(
		clr, enable : in  std_logic;
                data_in : in  std_logic_vector(7 downto 0);
                Done : in std_logic;
                dout : out std_logic_vector(7 downto 0)
	);
end PIPO_Shift_Left;

-- It is predefault to Shift Left

architecture Behavioral of PIPO_Shift_Left is
signal Q : std_logic_vector(7 downto 0);
begin
	process(done)
	begin
			if rising_edge(Done) then
			 if clr = '1' then
		  		Q <= "00000000";
   	 		elsif enable = '1' then				
					Q <= data_in;
				end if;
		 	end if;
	end process;
	
	 dout <= Q;
end Behavioral;
