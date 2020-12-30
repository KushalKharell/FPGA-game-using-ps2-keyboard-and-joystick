library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
 
entity ClockDivider is
Port (
    in_clk  :in std_logic; -- Signal representing clock
    outclk1, outclk2, outclk3 : out std_logic -- Returns a clock value
  
);
end ClockDivider;
 
architecture rtl of ClockDivider is

signal cnt1: std_logic_vector(25 downto 0);
signal cnt2: std_logic_vector(22 downto 0);
signal cnt3: std_logic_vector(16 downto 0);
signal s1, s2, s3: std_logic;

begin		
	-- Clock Division Block for Generators
     process (in_clk)
            begin
                if (in_clk'event and in_clk = '1') then
                     if cnt1 = "10111110101111000010000000" then
                        s1 <= not s1; -- toggle s
                        cnt1 <="00000000000000000000000000";
                    else
                        cnt1 <= cnt1 + 1;
                    end if;
               
                end if;
           end process;
    outclk1 <= s1;
	
	process (in_clk)
                begin
                    if (in_clk'event and in_clk = '1') then
                         if cnt2 = "10011000100101101000000" then
                            s2 <= not s2; -- toggle s
                            cnt2 <="00000000000000000000000";
                        else
                            cnt2 <= cnt2 + 1;
                        end if;
                   
                    end if;
               end process;
            outclk2 <= s2;
            
    process (in_clk)
                   begin
                       if (in_clk'event and in_clk = '1') then
                            if cnt3 = "11000011010100000" then
                               s3 <= not s3; -- toggle s
                               cnt3 <="00000000000000000";
                           else
                               cnt3 <= cnt3 + 1;
                           end if;
                      
                       end if;
                  end process;
             outclk3 <= s3;    
end rtl;