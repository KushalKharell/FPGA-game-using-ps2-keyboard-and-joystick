library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Multiple_7segmentDisplayWithClockDivider is
Port (
    clk2, clk3 :in std_logic;
    d0, d1, d2, d3: in std_logic_vector(3 downto 0);
    dp : out std_logic;
    channels : out std_logic_vector(3 downto 0);
    segs : out std_logic_vector(6 downto 0) 
);	
end Multiple_7segmentDisplayWithClockDivider;



architecture behavioral of Multiple_7segmentDisplayWithClockDivider is

signal intAn: std_logic_vector(3 downto 0):= "1110"; -- internal signal representing Anodes Values
signal value1 : std_logic_vector(3 downto 0);
signal value2 : std_logic_vector(3 downto 0); 
signal value3 : std_logic_vector(3 downto 0);
signal value4 : std_logic_vector(3 downto 0); 


begin	
  channels <= intAn;
  
    process (clk3) 
	begin
	
       if  (clk3'event and clk3 = '1') then
            if intAn <= "1110" then
                intAn <= "1101";
            end if;
            if intAn <= "1101" then
                intAn <= "1011";
            end if;
            if intAn <= "1011" then
                intAn <= "0111";                      
            end if; 
            if intAn <= "0111" then
                intAn <= "1110";                      
            end if;      
                                 
       end if;
    dp <= '0';
	end process;
	
	process (clk2) 
        begin
            if  (clk2'event and clk2 = '1') then
            value1 <= D0;
            value2 <= D1; 
            value3 <= D2;
            value4 <= D3;      
            end if;
            
    end process;
   	
	
    process (intAn) 
    begin
	
	if (intAn = "1110" ) THEN 
	    case value1 is
	 --   case counting is
		when "0000" => segs <= NOT "0111111"; -- 0
		when "0001" => segs <=NOT "0000110"; -- 1
		when "0010" => segs <=NOT "1011011"; -- 2
		when "0011" => segs <=NOT "1001111"; -- 3
		when "0100" => segs <=NOT "1100110"; -- 4
		when "0101" => segs <=NOT "1101101"; -- 5
		when "0110" => segs <=NOT "1111101"; -- 6
		when "0111" => segs <=NOT "0000111"; -- 7
		when "1000" => segs <=NOT "1111111"; -- 8
		when "1001" => segs <=NOT "1100111"; -- 9
		when "1010" => segs <=NOT "1110111"; -- A
		when "1011" => segs <=NOT "1111100"; -- b
		when "1100" => segs <=NOT "0111001"; -- c
		when "1101" => segs <=NOT "1011110"; -- d
		when "1110" => segs <=NOT "1111001"; -- E
		when others => segs <=NOT "1110001"; -- F
	    end case;
	    
	    end if;
	    
	    if (intAn = "0111" ) THEN 
	    
	    case value4 is
     --   case counting is
        when "0000" => segs <= NOT "0111111"; -- 0
        when "0001" => segs <=NOT "0000110"; -- 1
        when "0010" => segs <=NOT "1011011"; -- 2
        when "0011" => segs <=NOT "1001111"; -- 3
        when "0100" => segs <=NOT "1100110"; -- 4
        when "0101" => segs <=NOT "1101101"; -- 5
        when "0110" => segs <=NOT "1111101"; -- 6
        when "0111" => segs <=NOT "0000111"; -- 7
        when "1000" => segs <=NOT "1111111"; -- 8
        when "1001" => segs <=NOT "1100111"; -- 9
        when "1010" => segs <=NOT "1110111"; -- A
        when "1011" => segs <=NOT "1111100"; -- b
        when "1100" => segs <=NOT "0111001"; -- c
        when "1101" => segs <=NOT "1011110"; -- d
        when "1110" => segs <=NOT "1111001"; -- E
        when others => segs <=NOT "1110001"; -- F
        end case;
        
        end if ;
        
        if (intAn = "1101" ) THEN 
        case value2 is
     --   case counting is
        when "0000" => segs <= NOT "0111111"; -- 0
        when "0001" => segs <=NOT "0000110"; -- 1
        when "0010" => segs <=NOT "1011011"; -- 2
        when "0011" => segs <=NOT "1001111"; -- 3
        when "0100" => segs <=NOT "1100110"; -- 4
        when "0101" => segs <=NOT "1101101"; -- 5
        when "0110" => segs <=NOT "1111101"; -- 6
        when "0111" => segs <=NOT "0000111"; -- 7
        when "1000" => segs <=NOT "1111111"; -- 8
        when "1001" => segs <=NOT "1100111"; -- 9
        when "1010" => segs <=NOT "1110111"; -- A
        when "1011" => segs <=NOT "1111100"; -- b
        when "1100" => segs <=NOT "0111001"; -- c
        when "1101" => segs <=NOT "1011110"; -- d
        when "1110" => segs <=NOT "1111001"; -- E
        when others => segs <=NOT "1110001"; -- F
        end case;
        
        end if ;  
        
        if (intAn = "1011" ) THEN 
        case value3 is
     --   case counting is
        when "0000" => segs <= NOT "0111111"; -- 0
        when "0001" => segs <=NOT "0000110"; -- 1
        when "0010" => segs <=NOT "1011011"; -- 2
        when "0011" => segs <=NOT "1001111"; -- 3
        when "0100" => segs <=NOT "1100110"; -- 4
        when "0101" => segs <=NOT "1101101"; -- 5
        when "0110" => segs <=NOT "1111101"; -- 6
        when "0111" => segs <=NOT "0000111"; -- 7
        when "1000" => segs <=NOT "1111111"; -- 8
        when "1001" => segs <=NOT "1100111"; -- 9
        when "1010" => segs <=NOT "1110111"; -- A
        when "1011" => segs <=NOT "1111100"; -- b
        when "1100" => segs <=NOT "0111001"; -- c
        when "1101" => segs <=NOT "1011110"; -- d
        when "1110" => segs <=NOT "1111001"; -- E
        when others => segs <=NOT "1110001"; -- F
        end case;
        
        end if ;           
	
    end process;

end behavioral;
  
    