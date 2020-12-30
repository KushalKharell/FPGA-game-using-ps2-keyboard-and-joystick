---------------------------------------------------------------------------
-- This VHDL file was developed by Daniel Llamocca (2015).  It may be
-- freely copied and/or distributed at no cost.  Any persons using this
-- file for any purpose do so at their own risk, and are responsible for
-- the results of such use.  Daniel Llamocca does not guarantee that
-- this file is complete, correct, or fit for any particular purpose.
-- NO WARRANTY OF ANY KIND IS EXPRESSED OR IMPLIED.  This notice must
-- accompany any copy of this file.
--------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;


-- Output Data: 9 bits: DOUT(8): Stop bit (1). DOUT(7 downto 0): 8-bit data from keyboard
-- For each 9-bit output, the done is asserted for one clock cycle. Done is asserted when data is already available to capture.
-- Keyboard behavior: if a key is pressed and held, the scan code (8 bits, see Nexys4-DDR datashet) is sent every 100 ms
--                    Once the key is released, a keyup code is sent first (F0), followed by the 8-bit scan code.
--                    For all these instances (repeated scan code every 100 ms, keyup code, and scan code), the done signal is asserted
--                    for one clock cycle. Some keys send two keyup codes: E0 F0.
--                    If you want to only read one scan code, design an FSM that waits for the keyupcode (F0), and then retrieves the scan code once.
entity ps2keyboard is
	port (resetn, clock: in std_logic;
			ps2c, ps2d: in std_logic;
			DOUT: inout std_logic_vector (8 downto 0);
			sXDDD : out std_logic_vector (15 downto 0)
				
     );
	--		done: out std_logic);
end ps2keyboard;

architecture Behavioral of ps2keyboard is


--component count_display
--    Port ( 
		
--		value : in std_logic_vector(7 downto 0);
--		CLK100MHZ : in std_logic;
----	    RESETME : in std_logic;   
--		channels : out std_logic_vector(7 downto 0);
--	    segs : inout std_logic_vector(6 downto 0));
--	end component;

	component my_genpulse
		generic (COUNT: INTEGER:= (10**8)/2); -- (10**8)/2 cycles of T = 10 ns --> 0.5 us
		port (clock, resetn, E: in std_logic;
				Q: out std_logic_vector ( 31 downto 0);
				z: out std_logic);
	end component;
	
	component my_pashiftreg
		generic (N: INTEGER:= 4;
					DIR: STRING:= "LEFT");
		port ( clock, resetn: in std_logic;
				 din, E, s_l: in std_logic; -- din: shiftin input
				 D: in std_logic_vector (N-1 downto 0);
				 Q: out std_logic_vector (N-1 downto 0);
				 shiftout: out std_logic);
	end component;
	
	component dffe
        Port ( d : in  STD_LOGIC;
                clrn: in std_logic:= '1';
                  prn: in std_logic:= '1';
               clk : in  STD_LOGIC;
                  ena: in std_logic;
               q : out  STD_LOGIC);
    end component;
	
	type state is (S1, S2);
	signal y, yf: state;	
	
	signal done, doned, fall_edge, ps2cf, E, L, EQ, zQ: std_logic;
	signal Qfi: std_logic_vector (7 downto 0);
	
	signal XChannels :  std_logic_vector(3 downto 0);
	signal Xsegs :  std_logic_vector(6 downto 0);
	
	signal Buffer_out: std_logic_vector (7 downto 0);
	signal Buffer_out2: std_logic_vector (7 downto 0);
	signal XDDD :  std_logic_vector(7 downto 0);
 
    
    component PIPO_Shift_Left
        port(
            clr, enable : in  std_logic;
            data_in : in  std_logic_vector(7 downto 0);
            Done : in std_logic;
            dout : out std_logic_vector(7 downto 0)
        );
    end component;
    
begin



XDDD <= DOUT(7 downto 0);
sXDDD <= (Buffer_out2 & Buffer_out);


-- Counter: Modulo-9
gb: my_genpulse generic map (COUNT => 9)
	 port map (clock => clock, resetn => resetn, E => EQ, z => zQ);

--Parallel in parallel out shift left register
PP: PIPO_Shift_Left
    port map(clr => '0', enable => '1', data_in => XDDD, Done => done, dout => Buffer_out);
PP1: PIPO_Shift_Left
    port map(clr => '0', enable => '1', data_in => Buffer_out, Done => done, dout => Buffer_out2);
    
-- Shift Register
    sa: my_pashiftreg generic map (N => 9, DIR => "RIGHT")
        port map (clock => clock, resetn => resetn, din => ps2d, E => E, s_l => L, D => (others => '0'), Q => DOUT);
    
    -----------------------------------------------------
    -- Shift Register for ps2c: Filtering
    fi: my_pashiftreg generic map (N => 8, DIR => "RIGHT")
        port map (clock => clock, resetn => resetn, din => ps2c, E => '1', s_l => '0', D => (others => '0'), Q => Qfi);
         
    -- Filtering: A FF is created here
        process (resetn, clock, Qfi)
        begin
            if resetn = '0' then -- asynchronous signal
                ps2cf <= '0';
            elsif (clock'event and clock = '1') then
                if Qfi = "00000000" then
                    ps2cf <= '0';
                elsif Qfi = "11111111" then
                    ps2cf <= '1';
                end if;
            end if;        
        end process;          
    -----------------------------------------------------
    
    -- FSM: Falling Edge Detector
        Trans: process (resetn, clock, ps2cf)
        begin
            if resetn = '0' then -- asynchronous signal
                yf <= S1; -- if resetn asserted, go to initial state: S1            
            elsif (clock'event and clock = '1') then
                case yf is
                    when S1 =>
                        if ps2cf = '1' then yf <= S2; else yf <= S1; end if;
                        
                    when S2 =>
                        if ps2cf = '1' then yf <= S2; else yf <= S1; end if;
                end case;            
            end if;        
        end process;
        
        Output: process (yf, ps2cf)
        begin
            -- Initialization of FSM outputs:
            fall_edge <= '0';
            case yf is
                when S1 =>
                    
                when S2 =>
                    if ps2cf = '0' then fall_edge <= '1'; end if;
            end case;
        end process;
        
    -- Main FSM:
        Transitions: process (resetn, clock, fall_edge, ps2d, zQ)
        begin
            if resetn = '0' then -- asynchronous signal
                y <= S1; -- if resetn asserted, go to initial state: S1            
            elsif (clock'event and clock = '1') then
                case y is
                    when S1 =>
                        if fall_edge = '1' then
                            if ps2d = '1' then y <= S1; else y <= S2; end if;
                        else
                            y <= S1;
                        end if;
                    
                    when S2 =>
                        if fall_edge = '1' then
                            if zQ = '1' then y <= S1; else y <= S2; end if;
                        else
                            y <= S2;
                        end if;
                        
                end case;            
            end if;        
        end process;
        
        Outputs: process (y, zQ, fall_edge)
        begin
            -- Initialization of FSM outputs:
            E <= '0'; L <= '0'; doned <= '0'; EQ <= '0';
            case y is
                when S1 =>
                    
                when S2 =>
                    if fall_edge = '1' then
                        E <= '1';
                        EQ <= '1'; -- Q <= Q+1. If we reach the maximum count, then Q <= 0.
                        if zQ = '1' then doned <= '1'; end if;
                    end if;
            end case;
        end process;
        
    -- This is so that 'done' appears (for one clock cycle) at the same time output data (9 bits is available).    
    rd: dffe port map ( d => doned, clrn => resetn, prn => '1', clk => clock, ena => '1', q => done);
     
    end Behavioral;


