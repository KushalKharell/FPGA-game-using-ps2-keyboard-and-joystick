
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.std_logic_unsigned.all;

entity game is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        speed : in std_logic_vector(3 downto 0); 
        PlayerColor: in std_logic_vector(5 downto 0); --change the player1 and player2 color(each get 2 color picks)(sw(after speed, p1, p2))
        ps2c, ps2d: in std_logic;
        PushUp: in std_logic; --push button up for player 2 , for just testing purposes 
        PushDown: in std_logic; --puch button down for player 2, for just test purposes  
        --scoreswitch
        MISO: in std_logic;
        
        DOUT: inout std_logic_vector (8 downto 0);
        
        SS: out std_logic;
        MOSI: out std_logic;
        SCLK: out std_logic;
        LED: out std_logic_vector(2 downto 0);
        
        vgaRed : out STD_LOGIC_VECTOR(3 downto 0);
        vgaBlue : out STD_LOGIC_VECTOR(3 downto 0);
        vgaGreen : out STD_LOGIC_VECTOR(3 downto 0);
        Hsync : out STD_LOGIC;
        Vsync : out STD_LOGIC;
        
        segs : out std_logic_vector(6 downto 0);
        dp : out STD_LOGIC; --For seven segment display on Basys 3
        channels : out STD_LOGIC_VECTOR(3 downto 0) --For seven segment display on Basys 3
    );
end game;

architecture Behavioral of game is
    
    component ClockDivider is
    Port (
        in_clk  :in std_logic; -- Signal representing clock
        outclk1, outclk2, outclk3 : out std_logic -- Returns a clock value
    );
    end component;
    
    component Multiple_7segmentDisplayWithClockDivider is
    Port (
        clk2, clk3 :in std_logic;
        d0, d1, d2, d3: in std_logic_vector(3 downto 0);
        dp : out std_logic;
        channels : out std_logic_vector(3 downto 0);
        segs : out std_logic_vector(6 downto 0) 
    );	
    end component;
    
    component ps2keyboard is
    Port (resetn, clock: in std_logic;
        ps2c, ps2d: in std_logic;
        DOUT: inout std_logic_vector (8 downto 0);
        sXDDD : out std_logic_vector (15 downto 0)
    );
    end component;
    
    component PmodJSTK_Master is
    port (
        CLK: in std_logic;
        RST: in std_logic;
        MISO: in std_logic;
        SW: in std_logic_vector(2 downto 0);
        
        SS: out std_logic;
        MOSI: out std_logic;
        SCLK: out std_logic;
        LED: out std_logic_vector(2 downto 0);
        posData: out std_logic_vector(9 downto 0)
    );
    end component;
    
    signal btn_cnt : natural range 0 to 1000000;
    signal clk_cnt : natural range 0 to 500000;
    
    --All coordinates determines the left corner of an object
    signal posX : natural range 0 to 1280; --x position of the guy
    signal posY : natural range 0 to 1024; --y position of the guy
    
    signal X : natural range 0 to 1280;
    signal Y : natural range 0 to 1024;
    signal Red : natural range 0 to 15;
    signal Green : natural range 0 to 15;
    signal Blue : natural range 0 to 15;
	
    --signal btnU_DB : std_logic;
    --signal btnD_DB : std_logic;
    signal keyboard: std_logic_vector(15 downto 0);
    signal joy: std_logic_vector(9 downto 0);
	
	signal sizeOfGuy: natural := 50;
	constant centerX: natural := 640;
	constant centerY: natural := 512;
	constant heightOfBar: natural := 30;
	
	signal moveUp: std_logic; --determines if the guy is moving to up or not
	signal moveDown: std_logic; --determines if the guy is moving to down or not
	signal gameOver: std_logic; --a flag to end up the game
	signal speedOfGuy: natural;
	signal speedOfBars: natural;
	
	
	--Signals for guy 2 ---------------------------------
	    signal score2: natural range 0 to 9999; --score for player 2
        signal score_cnt2: natural range 0 to 10000000; --for player 2
        signal sizeOfGuy2: natural := 50; --size of second guy 
        signal speedOfGuy2: natural; --speed of second guy
        
         signal btn_cnt2 : natural range 0 to 1000000;
         signal clk_cnt2 : natural range 0 to 500000;
           
          
         signal posX2 : natural range 0 to 1280; --x position of the second guy
         signal posY2 : natural range 0 to 1024; --y position of the second guy
         
         signal curUp_cnt2: natural range 0 to 1000;
         signal curDown_cnt2: natural range 0 to 1000;
         
         signal moveUp2: std_logic; --move up for player 2
        signal moveDown2: std_logic; --move down for player 2
        
        signal gameOver2: std_logic; --a flag to end up the game only if(gameOver AND gameOver2)
        
	-----------------------------------------------------
	
	--Basically, there might be at most 5 bars can be seen on screen so the lenghts of each bar are
	--also 256 ( 1280/5 = 256)
    type int_array_Y is array (0 to 4) of natural range 0 to 1024;
	type int_array_X is array (0 to 4) of integer range -1280 to 3280;-- Up to 3280 For overflow issues
	type int_array_L is array (0 to 4) of integer range 0 to 500;
	
	--Upcoming bars are storaged as ROM to have a control on the places of bars. But for further
	--modification, random generators might be used as well.
	type int_array_Y_levels is array (0 to 99) of natural range 0 to 1024; 
	type int_array_L_levels is array (0 to 99) of integer range 0 to 300;
	
	--For now, just 2 bars paralel to each other is used. 3 or more bars might be used to increase difficulty
	signal upBarYPositions : int_array_Y;
	signal upBarLengths : int_array_L; --Parallel array with upBarYPositions
	signal upBarXPositions : int_array_X; --Parallel array with upBarYPositions
	
	signal downBarYPositions : int_array_Y;
	signal downBarLengths : int_array_L;
	signal downBarXPositions : int_array_X;
	
	--For later intermediary bars might be needed
	signal currentUpEdge: natural range 0 to 1024 := 0;
	signal currentDownEdge: natural range 0 to 1024 := 0;
	signal frame_count : natural range 0 to 1000000;

	--For next bars as the game progress, used as Rom but random generator implementation might be used as well
	constant upBarYPositionsNext : int_array_Y_levels   := (264,126,170,278,381,376,238,382,282,246,117,345,271,86,369,210,205,318,182,360,52,387,154,168,48,77,254,184,15,206,372,7,79,282,93,264,15,92,12,130,212,66,45,261,170,396,210,135,151,64,11,147,34,217,115,77,258,12,164,204,95,59,76,345,58,29,260,75,330,68,397,130,169,94,43,270,283,195,54,167,347,320,179,88,384,358,220,336,56,334,27,370,383,345,392,6,44,171,280,26);
	constant upBarLengthsNext : int_array_L_levels      := (256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256);	
	constant downBarYPositionsNext : int_array_Y_levels := (550,580,610,640,640,700,700,850,728,697,758,519,831,672,823,530,852,645,697,879,565,589,972,825,927,644,553,792,895,727,1005,605,760,617,791,608,608,794,932,655,670,799,650,892,919,972,550,509,832,548,618,693,884,707,586,653,830,892,656,909,935,871,656,871,889,865,759,636,749,519,729,753,611,850,813,958,879,783,543,999,963,757,734,659,777,529,594,866,512,516,950,686,502,886,912,886,783,872,978,699);
    constant downBarLengthsNext: int_array_L_levels     := (256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256);
    signal indexUpBarNext: natural range 0 to 99;
    signal indexDownBarNext : natural range 0 to 99;
    signal curUp_cnt: natural range 0 to 1000; --curUp_cnt and curDown_cnt are counters for the process where 
    signal curDown_cnt: natural range 0 to 1000;--current edge is determined. They are needed to decrease the frequency of the process
    
    
    
    
    signal in0, in1, in2, in3 : std_logic_vector( 3 downto 0); --Scores given as parameters to sevSeg_4digit
   
    signal outclk2, outclk3 : std_logic;
    signal score: natural range 0 to 9999; --Lets try changing the score to not natural type 
    signal score_cnt: natural range 0 to 10000000;
    
    signal scoreFinal: natural range 0 to 9999;  --score for player 2 
    signal score2Final: natural range 0 to 9999;    -- score for player 1

--converts the score integer into string to be displayed in vga
--loops did not work and this was done manually 
--up to max amount the game can have 
 function int_to_str(int : integer) return string is
    variable a : natural := 0;
    variable r : string(1 to 11);

begin
    a := abs (int);
    
   
   
 case a is
           when 0    => r := "0          ";
           when 1    => r := "1          ";
           when 2    => r := "2          ";
           when 3    => r := "3          ";
           when 4    => r := "4          ";
           when 5    => r := "5          ";
           when 6    => r := "6          ";
           when 7    => r := "7          ";
           when 8    => r := "8          ";
           when 9    => r := "9          ";
           when 10   => r := "10         ";
           when 11   => r := "11         ";
           when 12   => r := "12         ";
           when 13   => r := "13         ";
           when 14   => r := "14         ";
           when 15   => r := "15         ";
           when 16   => r := "16         ";
           when 17   => r := "17         ";
           when 18   => r := "18         ";
           when 19   => r := "19         ";
           when 20   => r := "20         ";
           when 21   => r := "21         ";
           when 22   => r := "22         ";
           when 23   => r := "23         ";
           when 24   => r := "24         ";
           when 25   => r := "25         ";
           when 26   => r := "26         ";
           when 27   => r := "27         ";
           when 28   => r := "28         ";
           when 29   => r := "29         ";
           when 30   => r := "30         ";
           when 31   => r := "31         ";
           when 32   => r := "32         ";
           when 33   => r := "33         ";
           when 34   => r := "34         ";
           when 35   => r := "35         ";
           when 36   => r := "36         ";
           when 37   => r := "37         ";
           when 38   => r := "38         ";
           when 39   => r := "39         ";
           when 40   => r := "40         ";
           when 41   => r := "41         ";
           when 42   => r := "42         ";
           when 43   => r := "43         ";
           when 44   => r := "44         ";
           when 45   => r := "45         ";
           when 46   => r := "46         ";
           when 47   => r := "47         ";
           when 48   => r := "48         ";
           when 49   => r := "49         ";
           when 50   => r := "50         ";
           when 51   => r := "51         ";
           when 52   => r := "52         ";
           when 53   => r := "53         ";
           when 54   => r := "54         ";
           when 55   => r := "55         ";
           when 56   => r := "56         ";
           when 57   => r := "57         ";
           when 58   => r := "58         ";
           when 59   => r := "59         ";
           when 60   => r := "60         ";
           when 61   => r := "61         ";
           when 62   => r := "62         ";
           when 63   => r := "63         ";
           when 64   => r := "64         ";
           when 65   => r := "65         ";
           when 66   => r := "66         ";
           when 67   => r := "67         ";
           when 68   => r := "68         ";
           when 69   => r := "69         ";
           when 70   => r := "70         ";
           when 71   => r := "71         ";
           when 72   => r := "72         ";
           when 73   => r := "73         ";
           when 74   => r := "74         ";
           when 75   => r := "75         ";
           when 76   => r := "76         ";
           when 77   => r := "77         ";
           when 78   => r := "78         ";
           when 79   => r := "79         ";
           when 80   => r := "80         ";
           when 81   => r := "81         ";
           when 82   => r := "82         ";
           when 83   => r := "83         ";
           when 84   => r := "84         ";
           when 85   => r := "85         ";
           when 86   => r := "86         ";
           when 87   => r := "87         ";
           when 88   => r := "88         ";
           when 89   => r := "89         ";
           when 90   => r := "90         ";
           when 91   => r := "91         ";
           when 92   => r := "92         ";
           when 93   => r := "93         ";
           when 94   => r := "94         ";
           when 95   => r := "95         ";
           when 96   => r := "96         ";
           when 97   => r := "97         ";
           when 98   => r := "98         ";
           when 99   => r := "99         ";
           when 100  => r := "100        ";
           when 101  => r := "101        ";
           when 102  => r := "102        ";
           when 103  => r := "103        ";
           when 104  => r := "104        ";
           when 105  => r := "105        ";
           when 106  => r := "106        ";
           when 107  => r := "107        ";
           when 108  => r := "108        ";
           when 109  => r := "109        ";
           when 110  => r := "110        ";
           when 111  => r := "111        ";
           when 112  => r := "112        ";
           when 113  => r := "113        ";
           when 114  => r := "114        ";
           when 115  => r := "115        ";
           when 116  => r := "116        ";
           when 117  => r := "117        ";
           when 118  => r := "118        ";
           when 119  => r := "119        ";
           when 120  => r := "120        ";
           when 121  => r := "121        ";
           when 122  => r := "122        ";
           when 123  => r := "123        ";
           when 124  => r := "124        ";
           when 125  => r := "125        ";
           when 126  => r := "126        ";
           when 127  => r := "127        ";
           when 128  => r := "128        ";
           when 129  => r := "129        ";
           when 130  => r := "130        ";
           when 131  => r := "131        ";
           when 132  => r := "132        ";
           when 133  => r := "133        ";
           when 134  => r := "134        ";
           when 135  => r := "135        ";
           when 136  => r := "136        ";
           when 137  => r := "137        ";
           when 138  => r := "138        ";
           when 139  => r := "139        ";
           when 140  => r := "140        ";
           when 141  => r := "141        ";
           when 142  => r := "142        ";
           when 143  => r := "143        ";
           when 144  => r := "144        ";
           when 145  => r := "145        ";
           when 146  => r := "146        ";
           when 147  => r := "147        ";
           when 148  => r := "148        ";
           when 149  => r := "149        ";
           when 150  => r := "150        ";
           when 151  => r := "151        ";
           when 152  => r := "152        ";
           when 153  => r := "153        ";
           when 154  => r := "154        ";
           when 155  => r := "155        ";
           when 156  => r := "156        ";
           when 157  => r := "157        ";
           when 158  => r := "158        ";
           when 159  => r := "159        ";
           when 160  => r := "160        ";
           when 161  => r := "161        ";
           when 162  => r := "162        ";
           when 163  => r := "163        ";
           when 164  => r := "164        ";
           when 165  => r := "165        ";
           when 166  => r := "166        ";
           when 167  => r := "167        ";
           when 168 => r := "168        ";
           when 169 => r := "169        ";
           when 170 => r := "170        ";
           when 171 => r := "171        ";
           when 172 => r := "172        ";
           when 173 => r := "173        ";
           when 174 => r := "174        ";
           when 175 => r := "175        ";
           when 176 => r := "176        ";
           when 177 => r := "177        ";
           when 178 => r := "178        ";
           when 179 => r := "179        ";
           when 180 => r := "180        ";
           when 181 => r := "181        ";
           when 182 => r := "182        ";
           when 183 => r := "183        ";
           when 184 => r := "184        ";
           when 185 => r := "185        ";
           when 186 => r := "186        ";
           when 187 => r := "187        ";
           when 188 => r := "188        ";
           when 189 => r := "189        ";
           when 190 => r := "190        ";
           when 191 => r := "191        ";
           when 192 => r := "192        ";
           when 193 => r := "193        ";
           when 194 => r := "194        ";
           when 195 => r := "195        ";
           when 196 => r := "196        ";
           when 197 => r := "197        ";
           when 198 => r := "198        ";
           when 199 => r := "199        ";
           when 200 => r := "200        ";
           when 201 => r := "201        ";
           when 202 => r := "202        ";
           when 203 => r := "203        ";
           when 204 => r := "204        ";
           when 205 => r := "205        ";
           when 206 => r := "206        ";
           when 207 => r := "207        ";
           when 208 => r := "208        ";
           when 209 => r := "209        ";
           when 210 => r := "210        ";
           when 211 => r := "211        ";
           when 212 => r := "212        ";
           when 213 => r := "213        ";
           when 214 => r := "214        ";
           when 215 => r := "215        ";
           when 216 => r := "216        ";
           when 217 => r := "217        ";
           when 218 => r := "218        ";
           when 219 => r := "219        ";
           when 220 => r := "220        ";
           when 221 => r := "221        ";
           when 222 => r := "222        ";
           when 223 => r := "223        ";
           when 224 => r := "224        ";
           when 225 => r := "225        ";
           when 226 => r := "226        ";
           when 227 => r := "227        ";
           when 228 => r := "228        ";
           when 229 => r := "229        ";
           when 230 => r := "230        ";
           when 231 => r := "231        ";
           when 232 => r := "232        ";
           when 233 => r := "233        ";
           when 234 => r := "234        ";
           when 235 => r := "235        ";
           when 236 => r := "236        ";
           when 237 => r := "237        ";
           when 238 => r := "238        ";
           when 239 => r := "239        ";
           when 240 => r := "240        ";
           when 241 => r := "241        ";
           when 242 => r := "242        ";
           when 243 => r := "243        ";
           when 244 => r := "244        ";
           when 245 => r := "245        ";
           when 246 => r := "246        ";
           when 247 => r := "247        ";
           when 248 => r := "248        ";
           when 249 => r := "249        ";
           when 250 => r := "250        ";
           when 251 => r := "251        ";
           when 252 => r := "252        ";
           when 253 => r := "253        ";
           when 254 => r := "254        ";
           when 255 => r := "255        ";
           when 256 => r := "256        ";
           when 257 => r := "257        ";
           when 258 => r := "258        ";
           when 259 => r := "259        ";
           when 260 => r := "260        ";
           when 261 => r := "261        ";
           when 262 => r := "262        ";
           when 263 => r := "263        ";
           when 264 => r := "264        ";
           when 265 => r := "265        ";
           when 266 => r := "266        ";
           when 267 => r := "267        ";
           when 268 => r := "268        ";
           when 269 => r := "269        ";
           when 270 => r := "270        ";
           when 271 => r := "271        ";
           when 272 => r := "272        ";
           when 273 => r := "273        ";
           when 274 => r := "274        ";
           when 275 => r := "275        ";
           when 276 => r := "276        ";
           when 277 => r := "277        ";
           when 278 => r := "278        ";
           when 279 => r := "279        ";
           when 280 => r := "280        ";
           when 281 => r := "281        ";
           when 282 => r := "282        ";
           when 283 => r := "283        ";
           when 284 => r := "284        ";
           when 285 => r := "285        ";
           when 286 => r := "286        ";
           when 287 => r := "287        ";
           when 288 => r := "288        ";
           when 289 => r := "289        ";
           when 290 => r := "290        ";
           when 291 => r := "291        ";
           when 292 => r := "292        ";
           when 293 => r := "293        ";
           when 294 => r := "294        ";
           when 295 => r := "295        ";
           when 296 => r := "296        ";
           when 297 => r := "297        ";
           when 298 => r := "298        ";
           when 299 => r := "299        ";
           when 300 => r := "300        ";
           when 301 => r := "301        ";
           when 302 => r := "302        ";
           when 303 => r := "303        ";
           when 304 => r := "304        ";
           when 305 => r := "305        ";
           when 306 => r := "306        ";
           when 307 => r := "307        ";
           when 308 => r := "308        ";
           when 309 => r := "309        ";
           when 310 => r := "310        ";
           when 311 => r := "311        ";
           when 312 => r := "312        ";
           when 313 => r := "313        ";
           when 314 => r := "314        ";
           when 315 => r := "315        ";
           when 316 => r := "316        ";
           when 317 => r := "317        ";
           when 318 => r := "318        ";
           when 319 => r := "319        ";
           when 320 => r := "320        ";
           when 321 => r := "321        ";
           when 322 => r := "322        ";
           when 323 => r := "323        ";
           when 324 => r := "324        ";
           when 325 => r := "325        ";
           when 326 => r := "326        ";
           when 327 => r := "327        ";
           when 328 => r := "328        ";
           when 329 => r := "329        ";
           when 330 => r := "330        ";
           when 331 => r := "331        ";
           when 332 => r := "332        ";
           when 333 => r := "333        ";
           when 334 => r := "334        ";
           when 335 => r := "335        ";
           when 336 => r := "336        ";
           when 337 => r := "337        ";
           when 338 => r := "338        ";
           when 339 => r := "339        ";
           when 340 => r := "340        ";
           when 341 => r := "341        ";
           when 342 => r := "342        ";
           when 343 => r := "343        ";
           when 344 => r := "344        ";
           when 345 => r := "345        ";
           when 346 => r := "346        ";
           when 347 => r := "347        ";
           when 348 => r := "348        ";
           when 349 => r := "349        ";
           when 350 => r := "350        ";
           when 351 => r := "351        ";
           when 352 => r := "352        ";
           when 353 => r := "353        ";
           when 354 => r := "354        ";
           when 355 => r := "355        ";
           when 356 => r := "356        ";
           when 357 => r := "357        ";
           when 358 => r := "358        ";
           when 359 => r := "359        ";
           when 360 => r := "360        ";
           when 361 => r := "361        ";
           when 362 => r := "362        ";
           when 363 => r := "363        ";
           when 364 => r := "364        ";
           when 365 => r := "365        ";
           when 366 => r := "366        ";
           when 367 => r := "367        ";
           when 368 => r := "368        ";
           when 369 => r := "369        ";
           when 370 => r := "370        ";
           when 371 => r := "371        ";
           when 372 => r := "372        ";
           when 373 => r := "373        ";
           when 374 => r := "374        ";
           when 375 => r := "375        ";
           when 376 => r := "376        ";
           when 377 => r := "377        ";
           when 378 => r := "378        ";
           when 379 => r := "379        ";
           when 380 => r := "380        ";
           when 381 => r := "381        ";
           when 382 => r := "382        ";
           when 383 => r := "383        ";
           when 384 => r := "384        ";
           when 385 => r := "385        ";
           when 386 => r := "386        ";
           when 387 => r := "387        ";
           when 388 => r := "388        ";
           when 389 => r := "389        ";
           when 390 => r := "390        ";
           when 391 => r := "391        ";
           when 392 => r := "392        ";
           when 393 => r := "393        ";
           when 394 => r := "394        ";
           when 395 => r := "395        ";
           when 396 => r := "396        ";
           when 397 => r := "397        ";
           when 398 => r := "398        ";
           when 399 => r := "399        ";
           when 400 => r := "400        ";
           when 401 => r := "401        ";
           when 402 => r := "402        ";
           when 403 => r := "403        ";
           when 404 => r := "404        ";
           when 405 => r := "405        ";
           when 406 => r := "406        ";
           when 407 => r := "407        ";
           when 408 => r := "408        ";
           when 409 => r := "409        ";
           when 410 => r := "410        ";
           when 411 => r := "411        ";
           when 412 => r := "412        ";
           when 413 => r := "413        ";
           when 414 => r := "414        ";
           when 415 => r := "415        ";
           when 416 => r := "416        ";
           when 417 => r := "417        ";
           when 418 => r := "418        ";
           when 419 => r := "419        ";
           when 420 => r := "420        ";
           when 421 => r := "421        ";
           when 422 => r := "422        ";
           when 423 => r := "423        ";
           when 424 => r := "424        ";
           when 425 => r := "425        ";
           when 426 => r := "426        ";
           when 427 => r := "427        ";
           when 428 => r := "428        ";
           when 429 => r := "429        ";
           when 430 => r := "430        ";
           when 431 => r := "431        ";
           when 432 => r := "432        ";
           when 433 => r := "433        ";
           when 434 => r := "434        ";
           when 435 => r := "435        ";
           when 436 => r := "436        ";
           when 437 => r := "437        ";
           when 438 => r := "438        ";
           when 439 => r := "439        ";
           when 440 => r := "440        ";
           when 441 => r := "441        ";
           when 442 => r := "442        ";
           when 443 => r := "443        ";
           when 444 => r := "444        ";
           when 445 => r := "445        ";
           when 446 => r := "446        ";
           when 447 => r := "447        ";
           when 448 => r := "448        ";
           when 449 => r := "449        ";
           when 450 => r := "450        ";
           when 451 => r := "451        ";
           when 452 => r := "452        ";
           when 453 => r := "453        ";
           when 454 => r := "454        ";
           when 455 => r := "455        ";
           when 456 => r := "456        ";
           when 457 => r := "457        ";
           when 458 => r := "458        ";
           when 459 => r := "459        ";
           when 460 => r := "460        ";
           when 461 => r := "461        ";
           when 462 => r := "462        ";
           when 463 => r := "463        ";
           when 464 => r := "464        ";
           when 465 => r := "465        ";
           when 466 => r := "466        ";
           when 467 => r := "467        ";
           when 468 => r := "468        ";
           when 469 => r := "469        ";
           when 470 => r := "470        ";
           when 471 => r := "471        ";
           when 472 => r := "472        ";
           when 473 => r := "473        ";
           when 474 => r := "474        ";
           when 475 => r := "475        ";
           when 476 => r := "476        ";
           when 477 => r := "477        ";
           when 478 => r := "478        ";
           when 479 => r := "479        ";
           when 480 => r := "480        ";
           when 481 => r := "481        ";
           when 482 => r := "482        ";
           when 483 => r := "483        ";
           when 484 => r := "484        ";
           when 485 => r := "485        ";
           when 486 => r := "486        ";
           when 487 => r := "487        ";
           when 488 => r := "488        ";
           when 489 => r := "489        ";
           when 490 => r := "490        ";
           when 491 => r := "491        ";
           when 492 => r := "492        ";
           when 493 => r := "493        ";
           when 494 => r := "494        ";
           when 495 => r := "495        ";
           when 496 => r := "496        ";
           when 497 => r := "497        ";
           when 498 => r := "498        ";
           when 499 => r := "499        ";
           when 500 => r := "500        ";
           when 501 => r := "501        ";
           when 502 => r := "502        ";
           when 503 => r := "503        ";
           when 504 => r := "504        ";
           when 505 => r := "505        ";
           when 506 => r := "506        ";
           when 507 => r := "507        ";
           when 508 => r := "508        ";
           when 509 => r := "509        ";
           when 510 => r := "510        ";
           when 511 => r := "511        ";
           when 512 => r := "512        ";
           when 513 => r := "513        ";
           when 514 => r := "514        ";
           when 515 => r := "515        ";
           when 516 => r := "516        ";
           when 517 => r := "517        ";
           when 518 => r := "518        ";
           when 519 => r := "519        ";
           when 520 => r := "520        ";
           when 521 => r := "521        ";
           when 522 => r := "522        ";
           when 523 => r := "523        ";
           when 524 => r := "524        ";
           when 525 => r := "525        ";
           when 526 => r := "526        ";
           when 527 => r := "527        ";
           when 528 => r := "528        ";
           when 529 => r := "529        ";
           when 530 => r := "530        ";
           when 531 => r := "531        ";
           when 532 => r := "532        ";
           when 533 => r := "533        ";
           when 534 => r := "534        ";
           when 535 => r := "535        ";
           when 536 => r := "536        ";
           when 537 => r := "537        ";
           when 538 => r := "538        ";
           when 539 => r := "539        ";
           when 540 => r := "540        ";
           when 541 => r := "541        ";
           when 542 => r := "542        ";
           when 543 => r := "543        ";
           when 544 => r := "544        ";
           when 545 => r := "545        ";
           when 546 => r := "546        ";
           when 547 => r := "547        ";
           when 548 => r := "548        ";
           when 549 => r := "549        ";
           when 550 => r := "550        ";
           when 551 => r := "551        ";
           when 552 => r := "552        ";
           when 553 => r := "553        ";
           when 554 => r := "554        ";
           when 555 => r := "555        ";
           when 556 => r := "556        ";
           when 557 => r := "557        ";
           when 558 => r := "558        ";
           when 559 => r := "559        ";
           when 560 => r := "560        ";
           when 561 => r := "561        ";
           when 562 => r := "562        ";
           when 563 => r := "563        ";
           when 564 => r := "564        ";
           when 565 => r := "565        ";
           when 566 => r := "566        ";
           when 567 => r := "567        ";
           when 568 => r := "568        ";
           when 569 => r := "569        ";
           when 570 => r := "570        ";
           when 571 => r := "571        ";
           when 572 => r := "572        ";
           when 573 => r := "573        ";
           when 574 => r := "574        ";
           when 575 => r := "575        ";
           when 576 => r := "576        ";
           when 577 => r := "577        ";
           when 578 => r := "578        ";
           when 579 => r := "579        ";
           when 580 => r := "580        ";
           when 581 => r := "581        ";
           when 582 => r := "582        ";
           when 583 => r := "583        ";
           when 584 => r := "584        ";
           when 585 => r := "585        ";
           when 586 => r := "586        ";
           when 587 => r := "587        ";
           when 588 => r := "588        ";
           when 589 => r := "589        ";
           when 590 => r := "590        ";
           when 591 => r := "591        ";
           when 592 => r := "592        ";
           when 593 => r := "593        ";
           when 594 => r := "594        ";
           when 595 => r := "595        ";
           when 596 => r := "596        ";
           when 597 => r := "597        ";
           when 598 => r := "598        ";
           when 599 => r := "599        ";
           when 600 => r := "600        ";
           when 601 => r := "601        ";
           when 602 => r := "602        ";
           when 603 => r := "603        ";
           when 604 => r := "604        ";
           when 605 => r := "605        ";
           when 606 => r := "606        ";
           when 607 => r := "607        ";
           when 608 => r := "608        ";
           when 609 => r := "609        ";
           when 610 => r := "610        ";
           when 611 => r := "611        ";
           when 612 => r := "612        ";
           when 613 => r := "613        ";
           when 614 => r := "614        ";
           when 615 => r := "615        ";
           when 616 => r := "616        ";
           when 617 => r := "617        ";
           when 618 => r := "618        ";
           when 619 => r := "619        ";
           when 620 => r := "620        ";
           when 621 => r := "621        ";
           when 622 => r := "622        ";
           when 623 => r := "623        ";
           when 624 => r := "624        ";
           when 625 => r := "625        ";
           when 626 => r := "626        ";
           when 627 => r := "627        ";
           when 628 => r := "628        ";
           when 629 => r := "629        ";
           when 630 => r := "630        ";
           when 631 => r := "631        ";
           when 632 => r := "632        ";
           when 633 => r := "633        ";
           when 634 => r := "634        ";
           when 635 => r := "635        ";
           when 636 => r := "636        ";
           when 637 => r := "637        ";
           when 638 => r := "638        ";
           when 639 => r := "639        ";
           when 640 => r := "640        ";
           when 641 => r := "641        ";
           when 642 => r := "642        ";
           when 643 => r := "643        ";
           when 644 => r := "644        ";
           when 645 => r := "645        ";
           when 646 => r := "646        ";
           when 647 => r := "647        ";
           when 648 => r := "648        ";
           when 649 => r := "649        ";
           when 650 => r := "650        ";
           when 651 => r := "651        ";
           when 652 => r := "652        ";
           when 653 => r := "653        ";
           when 654 => r := "654        ";
           when 655 => r := "655        ";
           when 656 => r := "656        ";
           when 657 => r := "657        ";
           when 658 => r := "658        ";
           when 659 => r := "659        ";
           when 660 => r := "660        ";
           when 661 => r := "661        ";
           when 662 => r := "662        ";
           when 663 => r := "663        ";
           when 664 => r := "664        ";
           when 665 => r := "665        ";
           when 666 => r := "666        ";
           when 667 => r := "667        ";
           when 668 => r := "668        ";
           when 669 => r := "669        ";
           when 670 => r := "670        ";
           when 671 => r := "671        ";
           when 672 => r := "672        ";
           when 673 => r := "673        ";
           when 674 => r := "674        ";
           when 675 => r := "675        ";
           when 676 => r := "676        ";
           when 677 => r := "677        ";
           when 678 => r := "678        ";
           when 679 => r := "679        ";
           when 680 => r := "680        ";
           when 681 => r := "681        ";
           when 682 => r := "682        ";
           when 683 => r := "683        ";
           when 684 => r := "684        ";
           when 685 => r := "685        ";
           when 686 => r := "686        ";
           when 687 => r := "687        ";
           when 688 => r := "688        ";
           when 689 => r := "689        ";
           when 690 => r := "690        ";
           when 691 => r := "691        ";
           when 692 => r := "692        ";
           when 693 => r := "693        ";
           when 694 => r := "694        ";
           when 695 => r := "695        ";
           when 696 => r := "696        ";
           when 697 => r := "697        ";
           when 698 => r := "698        ";
           when 699 => r := "699        ";
           when 700 => r := "700        ";
           when 701 => r := "701        ";
           when 702 => r := "702        ";
           when 703 => r := "703        ";
           when 704 => r := "704        ";
           when 705 => r := "705        ";
           when 706 => r := "706        ";
           when 707 => r := "707        ";
           when 708 => r := "708        ";
           when 709 => r := "709        ";
           when 710 => r := "710        ";
           when 711 => r := "711        ";
           when 712 => r := "712        ";
           when 713 => r := "713        ";
           when 714 => r := "714        ";
           when 715 => r := "715        ";
           when 716 => r := "716        ";
           when 717 => r := "717        ";
           when 718 => r := "718        ";
           when 719 => r := "719        ";
           when 720 => r := "720        ";
           when 721 => r := "721        ";
           when 722 => r := "722        ";
           when 723 => r := "723        ";
           when 724 => r := "724        ";
           when 725 => r := "725        ";
           when 726 => r := "726        ";
           when 727 => r := "727        ";
           when 728 => r := "728        ";
           when 729 => r := "729        ";
           when 730 => r := "730        ";
           when 731 => r := "731        ";
           when 732 => r := "732        ";
           when 733 => r := "733        ";
           when 734 => r := "734        ";
           when 735 => r := "735        ";
           when 736 => r := "736        ";
           when 737 => r := "737        ";
           when 738 => r := "738        ";
           when 739 => r := "739        ";
           when 740 => r := "740        ";
           when 741 => r := "741        ";
           when 742 => r := "742        ";
           when 743 => r := "743        ";
           when 744 => r := "744        ";
           when 745 => r := "745        ";
           when 746 => r := "746        ";
           when 747 => r := "747        ";
           when 748 => r := "748        ";
           when 749 => r := "749        ";
           when 750 => r := "750        ";
           when 751 => r := "751        ";
           when 752 => r := "752        ";
           when 753 => r := "753        ";
           when 754 => r := "754        ";
           when 755 => r := "755        ";
           when 756 => r := "756        ";
           when 757 => r := "757        ";
           when 758 => r := "758        ";
           when 759 => r := "759        ";
           when 760 => r := "760        ";
           when 761 => r := "761        ";
           when 762 => r := "762        ";
           when 763 => r := "763        ";
           when 764 => r := "764        ";
           when 765 => r := "765        ";
           when 766 => r := "766        ";
           when 767 => r := "767        ";
           when 768 => r := "768        ";
           when 769 => r := "769        ";
           when 770 => r := "770        ";
           when 771 => r := "771        ";
           when 772 => r := "772        ";
           when 773 => r := "773        ";
           when 774 => r := "774        ";
           when 775 => r := "775        ";
           when 776 => r := "776        ";
           when 777 => r := "777        ";
           when 778 => r := "778        ";
           when 779 => r := "779        ";
           when 780 => r := "780        ";
           when 781 => r := "781        ";
           when 782 => r := "782        ";
           when 783 => r := "783        ";
           when 784 => r := "784        ";
           when 785 => r := "785        ";
           when 786 => r := "786        ";
           when 787 => r := "787        ";
           when 788 => r := "788        ";
           when 789 => r := "789        ";
           when 790 => r := "790        ";
           when 791 => r := "791        ";
           when 792 => r := "792        ";
           when 793 => r := "793        ";
           when 794 => r := "794        ";
           when 795 => r := "795        ";
           when 796 => r := "796        ";
           when 797 => r := "797        ";
           when 798 => r := "798        ";
           when 799 => r := "799        ";
           when 800 => r := "800        ";
           when 801 => r := "801        ";
           when 802 => r := "802        ";
           when 803 => r := "803        ";
           when 804 => r := "804        ";
           when 805 => r := "805        ";
           when 806 => r := "806        ";
           when 807 => r := "807        ";
           when 808 => r := "808        ";
           when 809 => r := "809        ";
           when 810 => r := "810        ";
           when 811 => r := "811        ";
           when 812 => r := "812        ";
           when 813 => r := "813        ";
           when 814 => r := "814        ";
           when 815 => r := "815        ";
           when 816 => r := "816        ";
           when 817 => r := "817        ";
           when 818 => r := "818        ";
           when 819 => r := "819        ";
           when 820 => r := "820        ";
           when 821 => r := "821        ";
           when 822 => r := "822        ";
           when 823 => r := "823        ";
           when 824 => r := "824        ";
           when 825 => r := "825        ";
           when 826 => r := "826        ";
           when 827 => r := "827        ";
           when 828 => r := "828        ";
           when 829 => r := "829        ";
           when 830 => r := "830        ";
           when 831 => r := "831        ";
           when 832 => r := "832        ";
           when 833 => r := "833        ";
           when 834 => r := "834        ";
           when 835 => r := "835        ";
           when 836 => r := "836        ";
           when 837 => r := "837        ";
           when 838 => r := "838        ";
           when 839 => r := "839        ";
           when 840 => r := "840        ";
           when 841 => r := "841        ";
           when 842 => r := "842        ";
           when 843 => r := "843        ";
           when 844 => r := "844        ";
           when 845 => r := "845        ";
           when 846 => r := "846        ";
           when 847 => r := "847        ";
           when 848 => r := "848        ";
           when 849 => r := "849        ";
           when 850 => r := "850        ";
           when 851 => r := "851        ";
           when 852 => r := "852        ";
           when 853 => r := "853        ";
           when 854 => r := "854        ";
           when 855 => r := "855        ";
           when 856 => r := "856        ";
           when 857 => r := "857        ";
           when 858 => r := "858        ";
           when 859 => r := "859        ";
           when 860 => r := "860        ";
           when 861 => r := "861        ";
           when 862 => r := "862        ";
           when 863 => r := "863        ";
           when 864 => r := "864        ";
           when 865 => r := "865        ";
           when 866 => r := "866        ";
           when 867 => r := "867        ";
           when 868 => r := "868        ";
           when 869 => r := "869        ";
           when 870 => r := "870        ";
           when 871 => r := "871        ";
           when 872 => r := "872        ";
           when 873 => r := "873        ";
           when 874 => r := "874        ";
           when 875 => r := "875        ";
           when 876 => r := "876        ";
           when 877 => r := "877        ";
           when 878 => r := "878        ";
           when 879 => r := "879        ";
           when 880 => r := "880        ";
           when 881 => r := "881        ";
           when 882 => r := "882        ";
           when 883 => r := "883        ";
           when 884 => r := "884        ";
           when 885 => r := "885        ";
           when 886 => r := "886        ";
           when 887 => r := "887        ";
           when 888 => r := "888        ";
           when 889 => r := "889        ";
           when 890 => r := "890        ";
           when 891 => r := "891        ";
           when 892 => r := "892        ";
           when 893 => r := "893        ";
           when 894 => r := "894        ";
           when 895 => r := "895        ";
           when 896 => r := "896        ";
           when 897 => r := "897        ";
           when 898 => r := "898        ";
           when 899 => r := "899        ";
           when 900 => r := "900        ";
           when 901 => r := "901        ";
           when 902 => r := "902        ";
           when 903 => r := "903        ";
           when 904 => r := "904        ";
           when 905 => r := "905        ";
           when 906 => r := "906        ";
           when 907 => r := "907        ";
           when 908 => r := "908        ";
           when 909 => r := "909        ";
           when 910 => r := "910        ";
           when 911 => r := "911        ";
           when 912 => r := "912        ";
           when 913 => r := "913        ";
           when 914 => r := "914        ";
           when 915 => r := "915        ";
           when 916 => r := "916        ";
           when 917 => r := "917        ";
           when 918 => r := "918        ";
           when 919 => r := "919        ";
           when 920 => r := "920        ";
           when 921 => r := "921        ";
           when 922 => r := "922        ";
           when 923 => r := "923        ";
           when 924 => r := "924        ";
           when 925 => r := "925        ";
           when 926 => r := "926        ";
           when 927 => r := "927        ";
           when 928 => r := "928        ";
           when 929 => r := "929        ";
           when 930 => r := "930        ";
           when 931 => r := "931        ";
           when 932 => r := "932        ";
           when 933 => r := "933        ";
           when 934 => r := "934        ";
           when 935 => r := "935        ";
           when 936 => r := "936        ";
           when 937 => r := "937        ";
           when 938 => r := "938        ";
           when 939 => r := "939        ";
           when 940 => r := "940        ";
           when 941 => r := "941        ";
           when 942 => r := "942        ";
           when 943 => r := "943        ";
           when 944 => r := "944        ";
           when 945 => r := "945        ";
           when 946 => r := "946        ";
           when 947 => r := "947        ";
           when 948 => r := "948        ";
           when 949 => r := "949        ";
           when 950 => r := "950        ";
           when 951 => r := "951        ";
           when 952 => r := "952        ";
           when 953 => r := "953        ";
           when 954 => r := "954        ";
           when 955 => r := "955        ";
           when 956 => r := "956        ";
           when 957 => r := "957        ";
           when 958 => r := "958        ";
           when 959 => r := "959        ";
           when 960 => r := "960        ";
           when 961 => r := "961        ";
           when 962 => r := "962        ";
           when 963 => r := "963        ";
           when 964 => r := "964        ";
           when 965 => r := "965        ";
           when 966 => r := "966        ";
           when 967 => r := "967        ";
           when 968 => r := "968        ";
           when 969 => r := "969        ";
           when 970 => r := "970        ";
           when 971 => r := "971        ";
           when 972 => r := "972        ";
           when 973 => r := "973        ";
           when 974 => r := "974        ";
           when 975 => r := "975        ";
           when 976 => r := "976        ";
           when 977 => r := "977        ";
           when 978 => r := "978        ";
           when 979 => r := "979        ";
           when 980 => r := "980        ";
           when 981 => r := "981        ";
           when 982 => r := "982        ";
           when 983 => r := "983        ";
           when 984 => r := "984        ";
           when 985 => r := "985        ";
           when 986 => r := "986        ";
           when 987 => r := "987        ";
           when 988 => r := "988        ";
           when 989 => r := "989        ";
           when 990 => r := "990        ";
           when 991 => r := "991        ";
           when 992 => r := "992        ";
           when 993 => r := "993        ";
           when 994 => r := "994        ";
           when 995 => r := "995        ";
           when 996 => r := "996        ";
           when 997 => r := "997        ";
           when 998 => r := "998        ";
           when 999 => r := "999        ";
           
           --I need to find a new way to implement score because this is too much manual labor to do. 
           
           when 1000 => r := "1000       ";
   
           when others => r := "???????????";
       end case;

    if (int < 0) then
        r := '-' & r(1 to 10);
    end if;

    return r;
end int_to_str;

--Another attempt to display the score without putting so much manual work 

 



    function draw_char(X : natural; Y : natural; char : character) return boolean is
            constant ADDR_WIDTH: integer:=11;
            constant DATA_WIDTH: integer:=8;
            type rom_type is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
           -- ROM definition
           constant ROM: rom_type:=(   -- 2^11-by-8
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x01 ?
           "00000000", -- 0
           "00000000", -- 1
           "01111110", -- 2  ******
           "10000001", -- 3 *      *
           "10100101", -- 4 * *  * *
           "10000001", -- 5 *      *
           "10000001", -- 6 *      *
           "10111101", -- 7 * **** *
           "10011001", -- 8 *  **  *
           "10000001", -- 9 *      *
           "10000001", -- a *      *
           "01111110", -- b  ******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x02 ?
           "00000000", -- 0
           "00000000", -- 1
           "01111110", -- 2  ******
           "11111111", -- 3 ********
           "11011011", -- 4 ** ** **
           "11111111", -- 5 ********
           "11111111", -- 6 ********
           "11000011", -- 7 **    **
           "11100111", -- 8 ***  ***
           "11111111", -- 9 ********
           "11111111", -- a ********
           "01111110", -- b  ******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x03 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "01101100", -- 4  ** **
           "11111110", -- 5 *******
           "11111110", -- 6 *******
           "11111110", -- 7 *******
           "11111110", -- 8 *******
           "01111100", -- 9  *****
           "00111000", -- a   ***
           "00010000", -- b    *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x04 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00010000", -- 4    *
           "00111000", -- 5   ***
           "01111100", -- 6  *****
           "11111110", -- 7 *******
           "01111100", -- 8  *****
           "00111000", -- 9   ***
           "00010000", -- a    *
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x05 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00011000", -- 3    **
           "00111100", -- 4   ****
           "00111100", -- 5   ****
           "11100111", -- 6 ***  ***
           "11100111", -- 7 ***  ***
           "11100111", -- 8 ***  ***
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x06 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00011000", -- 3    **
           "00111100", -- 4   ****
           "01111110", -- 5  ******
           "11111111", -- 6 ********
           "11111111", -- 7 ********
           "01111110", -- 8  ******
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x07 •
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00011000", -- 6    **
           "00111100", -- 7   ****
           "00111100", -- 8   ****
           "00011000", -- 9    **
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x08 ?
           "11111111", -- 0 ********
           "11111111", -- 1 ********
           "11111111", -- 2 ********
           "11111111", -- 3 ********
           "11111111", -- 4 ********
           "11111111", -- 5 ********
           "11100111", -- 6 ***  ***
           "11000011", -- 7 **    **
           "11000011", -- 8 **    **
           "11100111", -- 9 ***  ***
           "11111111", -- a ********
           "11111111", -- b ********
           "11111111", -- c ********
           "11111111", -- d ********
           "11111111", -- e ********
           "11111111", -- f ********
           -- code x09 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00111100", -- 5   ****
           "01100110", -- 6  **  **
           "01000010", -- 7  *    *
           "01000010", -- 8  *    *
           "01100110", -- 9  **  **
           "00111100", -- a   ****
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x0a ?
           "11111111", -- 0 ********
           "11111111", -- 1 ********
           "11111111", -- 2 ********
           "11111111", -- 3 ********
           "11111111", -- 4 ********
           "11000011", -- 5 **    **
           "10011001", -- 6 *  **  *
           "10111101", -- 7 * **** *
           "10111101", -- 8 * **** *
           "10011001", -- 9 *  **  *
           "11000011", -- a **    **
           "11111111", -- b ********
           "11111111", -- c ********
           "11111111", -- d ********
           "11111111", -- e ********
           "11111111", -- f ********
           -- code x0b ?
           "00000000", -- 0
           "00000000", -- 1
           "00011110", -- 2    ****
           "00001110", -- 3     ***
           "00011010", -- 4    ** *
           "00110010", -- 5   **  *
           "01111000", -- 6  ****
           "11001100", -- 7 **  **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01111000", -- b  ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x0c ?
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01100110", -- 6  **  **
           "00111100", -- 7   ****
           "00011000", -- 8    **
           "01111110", -- 9  ******
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x0d ?
           "00000000", -- 0
           "00000000", -- 1
           "00111111", -- 2   ******
           "00110011", -- 3   **  **
           "00111111", -- 4   ******
           "00110000", -- 5   **
           "00110000", -- 6   **
           "00110000", -- 7   **
           "00110000", -- 8   **
           "01110000", -- 9  ***
           "11110000", -- a ****
           "11100000", -- b ***
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x0e ?
           "00000000", -- 0
           "00000000", -- 1
           "01111111", -- 2  *******
           "01100011", -- 3  **   **
           "01111111", -- 4  *******
           "01100011", -- 5  **   **
           "01100011", -- 6  **   **
           "01100011", -- 7  **   **
           "01100011", -- 8  **   **
           "01100111", -- 9  **  ***
           "11100111", -- a ***  ***
           "11100110", -- b ***  **
           "11000000", -- c **
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x0f ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00011000", -- 3    **
           "00011000", -- 4    **
           "11011011", -- 5 ** ** **
           "00111100", -- 6   ****
           "11100111", -- 7 ***  ***
           "00111100", -- 8   ****
           "11011011", -- 9 ** ** **
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x10 ?
           "00000000", -- 0
           "10000000", -- 1 *
           "11000000", -- 2 **
           "11100000", -- 3 ***
           "11110000", -- 4 ****
           "11111000", -- 5 *****
           "11111110", -- 6 *******
           "11111000", -- 7 *****
           "11110000", -- 8 ****
           "11100000", -- 9 ***
           "11000000", -- a **
           "10000000", -- b *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x11 ?
           "00000000", -- 0
           "00000010", -- 1       *
           "00000110", -- 2      **
           "00001110", -- 3     ***
           "00011110", -- 4    ****
           "00111110", -- 5   *****
           "11111110", -- 6 *******
           "00111110", -- 7   *****
           "00011110", -- 8    ****
           "00001110", -- 9     ***
           "00000110", -- a      **
           "00000010", -- b       *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x12 ?
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00111100", -- 3   ****
           "01111110", -- 4  ******
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "01111110", -- 8  ******
           "00111100", -- 9   ****
           "00011000", -- a    **
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x13 ?
           "00000000", -- 0
           "00000000", -- 1
           "01100110", -- 2  **  **
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01100110", -- 6  **  **
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "00000000", -- 9
           "01100110", -- a  **  **
           "01100110", -- b  **  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x14 ¶
           "00000000", -- 0
           "00000000", -- 1
           "01111111", -- 2  *******
           "11011011", -- 3 ** ** **
           "11011011", -- 4 ** ** **
           "11011011", -- 5 ** ** **
           "01111011", -- 6  **** **
           "00011011", -- 7    ** **
           "00011011", -- 8    ** **
           "00011011", -- 9    ** **
           "00011011", -- a    ** **
           "00011011", -- b    ** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x15 §
           "00000000", -- 0
           "01111100", -- 1  *****
           "11000110", -- 2 **   **
           "01100000", -- 3  **
           "00111000", -- 4   ***
           "01101100", -- 5  ** **
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "01101100", -- 8  ** **
           "00111000", -- 9   ***
           "00001100", -- a     **
           "11000110", -- b **   **
           "01111100", -- c  *****
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x16 ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "11111110", -- 8 *******
           "11111110", -- 9 *******
           "11111110", -- a *******
           "11111110", -- b *******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x17 ?
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00111100", -- 3   ****
           "01111110", -- 4  ******
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "01111110", -- 8  ******
           "00111100", -- 9   ****
           "00011000", -- a    **
           "01111110", -- b  ******
           "00110000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x18 ?
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00111100", -- 3   ****
           "01111110", -- 4  ******
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x19 ?
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "01111110", -- 9  ******
           "00111100", -- a   ****
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1a ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00011000", -- 5    **
           "00001100", -- 6     **
           "11111110", -- 7 *******
           "00001100", -- 8     **
           "00011000", -- 9    **
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1b ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00110000", -- 5   **
           "01100000", -- 6  **
           "11111110", -- 7 *******
           "01100000", -- 8  **
           "00110000", -- 9   **
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1c ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "11000000", -- 6 **
           "11000000", -- 7 **
           "11000000", -- 8 **
           "11111110", -- 9 *******
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1d ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00100100", -- 5   *  *
           "01100110", -- 6  **  **
           "11111111", -- 7 ********
           "01100110", -- 8  **  **
           "00100100", -- 9   *  *
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1e ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00010000", -- 4    *
           "00111000", -- 5   ***
           "00111000", -- 6   ***
           "01111100", -- 7  *****
           "01111100", -- 8  *****
           "11111110", -- 9 *******
           "11111110", -- a *******
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x1f ?
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "11111110", -- 4 *******
           "11111110", -- 5 *******
           "01111100", -- 6  *****
           "01111100", -- 7  *****
           "00111000", -- 8   ***
           "00111000", -- 9   ***
           "00010000", -- a    *
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x20 ' '
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x21 !
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00111100", -- 3   ****
           "00111100", -- 4   ****
           "00111100", -- 5   ****
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00000000", -- 9
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x22 "
           "00000000", -- 0
           "01100110", -- 1  **  **
           "01100110", -- 2  **  **
           "01100110", -- 3  **  **
           "00100100", -- 4   *  *
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x23 #
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "01101100", -- 3  ** **
           "01101100", -- 4  ** **
           "11111110", -- 5 *******
           "01101100", -- 6  ** **
           "01101100", -- 7  ** **
           "01101100", -- 8  ** **
           "11111110", -- 9 *******
           "01101100", -- a  ** **
           "01101100", -- b  ** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x24 $
           "00011000", -- 0     **
           "00011000", -- 1     **
           "01111100", -- 2   *****
           "11000110", -- 3  **   **
           "11000010", -- 4  **    *
           "11000000", -- 5  **
           "01111100", -- 6   *****
           "00000110", -- 7       **
           "00000110", -- 8       **
           "10000110", -- 9  *    **
           "11000110", -- a  **   **
           "01111100", -- b   *****
           "00011000", -- c     **
           "00011000", -- d     **
           "00000000", -- e
           "00000000", -- f
           -- code x25 %
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "11000010", -- 4 **    *
           "11000110", -- 5 **   **
           "00001100", -- 6     **
           "00011000", -- 7    **
           "00110000", -- 8   **
           "01100000", -- 9  **
           "11000110", -- a **   **
           "10000110", -- b *    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x26 &
           "00000000", -- 0
           "00000000", -- 1
           "00111000", -- 2   ***
           "01101100", -- 3  ** **
           "01101100", -- 4  ** **
           "00111000", -- 5   ***
           "01110110", -- 6  *** **
           "11011100", -- 7 ** ***
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01110110", -- b  *** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x27 '
           "00000000", -- 0
           "00110000", -- 1   **
           "00110000", -- 2   **
           "00110000", -- 3   **
           "01100000", -- 4  **
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x28 (
           "00000000", -- 0
           "00000000", -- 1
           "00001100", -- 2     **
           "00011000", -- 3    **
           "00110000", -- 4   **
           "00110000", -- 5   **
           "00110000", -- 6   **
           "00110000", -- 7   **
           "00110000", -- 8   **
           "00110000", -- 9   **
           "00011000", -- a    **
           "00001100", -- b     **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x29 )
           "00000000", -- 0
           "00000000", -- 1
           "00110000", -- 2   **
           "00011000", -- 3    **
           "00001100", -- 4     **
           "00001100", -- 5     **
           "00001100", -- 6     **
           "00001100", -- 7     **
           "00001100", -- 8     **
           "00001100", -- 9     **
           "00011000", -- a    **
           "00110000", -- b   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2a *
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01100110", -- 5  **  **
           "00111100", -- 6   ****
           "11111111", -- 7 ********
           "00111100", -- 8   ****
           "01100110", -- 9  **  **
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2b +
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00011000", -- 5    **
           "00011000", -- 6    **
           "01111110", -- 7  ******
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2c ,
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00011000", -- 9    **
           "00011000", -- a    **
           "00011000", -- b    **
           "00110000", -- c   **
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2d -
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "01111110", -- 7  ******
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2e  .
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x2f /
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000010", -- 4       *
           "00000110", -- 5      **
           "00001100", -- 6     **
           "00011000", -- 7    **
           "00110000", -- 8   **
           "01100000", -- 9  **
           "11000000", -- a **
           "10000000", -- b *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x30
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11001110", -- 5 **  ***
           "11011110", -- 6 ** ****
           "11110110", -- 7 **** **
           "11100110", -- 8 ***  **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x31 
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2
           "00111000", -- 3
           "01111000", -- 4    **
           "00011000", -- 5   ***
           "00011000", -- 6  ****
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "01111110", -- b    **
           "00000000", -- c    **
           "00000000", -- d  ******
           "00000000", -- e
           "00000000", -- f
           -- code x32
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "00000110", -- 4      **
           "00001100", -- 5     **
           "00011000", -- 6    **
           "00110000", -- 7   **
           "01100000", -- 8  **
           "11000000", -- 9 **
           "11000110", -- a **   **
           "11111110", -- b *******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x33
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "00000110", -- 4      **
           "00000110", -- 5      **
           "00111100", -- 6   ****
           "00000110", -- 7      **
           "00000110", -- 8      **
           "00000110", -- 9      **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x34
           "00000000", -- 0
           "00000000", -- 1
           "00001100", -- 2     **
           "00011100", -- 3    ***
           "00111100", -- 4   ****
           "01101100", -- 5  ** **
           "11001100", -- 6 **  **
           "11111110", -- 7 *******
           "00001100", -- 8     **
           "00001100", -- 9     **
           "00001100", -- a     **
           "00011110", -- b    ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x35
           "00000000", -- 0
           "00000000", -- 1
           "11111110", -- 2 *******
           "11000000", -- 3 **
           "11000000", -- 4 **
           "11000000", -- 5 **
           "11111100", -- 6 ******
           "00000110", -- 7      **
           "00000110", -- 8      **
           "00000110", -- 9      **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x36
           "00000000", -- 0
           "00000000", -- 1
           "00111000", -- 2   ***
           "01100000", -- 3  **
           "11000000", -- 4 **
           "11000000", -- 5 **
           "11111100", -- 6 ******
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x37
           "00000000", -- 0
           "00000000", -- 1
           "11111110", -- 2 *******
           "11000110", -- 3 **   **
           "00000110", -- 4      **
           "00000110", -- 5      **
           "00001100", -- 6     **
           "00011000", -- 7    **
           "00110000", -- 8   **
           "00110000", -- 9   **
           "00110000", -- a   **
           "00110000", -- b   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x38
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "01111100", -- 6  *****
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x39
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "01111110", -- 6  ******
           "00000110", -- 7      **
           "00000110", -- 8      **
           "00000110", -- 9      **
           "00001100", -- a     **
           "01111000", -- b  ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3a :
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00011000", -- 9    **
           "00011000", -- a    **
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3b ;
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00011000", -- 9    **
           "00011000", -- a    **
           "00110000", -- b   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3c <
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000110", -- 3      **
           "00001100", -- 4     **
           "00011000", -- 5    **
           "00110000", -- 6   **
           "01100000", -- 7  **
           "00110000", -- 8   **
           "00011000", -- 9    **
           "00001100", -- a     **
           "00000110", -- b      **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3d =
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111110", -- 5  ******
           "00000000", -- 6
           "00000000", -- 7
           "01111110", -- 8  ******
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3e >
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "01100000", -- 3  **
           "00110000", -- 4   **
           "00011000", -- 5    **
           "00001100", -- 6     **
           "00000110", -- 7      **
           "00001100", -- 8     **
           "00011000", -- 9    **
           "00110000", -- a   **
           "01100000", -- b  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x3f ?
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "00001100", -- 5     **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00000000", -- 9
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x40 @
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "11011110", -- 6 ** ****
           "11011110", -- 7 ** ****
           "11011110", -- 8 ** ****
           "11011100", -- 9 ** ***
           "11000000", -- a **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x41
           "00000000", -- 0
           "00000000", -- 1
           "00010000", -- 2    *
           "00111000", -- 3   ***
           "01101100", -- 4  ** **
           "11000110", -- 5 **   **
           "11000110", -- 6 **   **
           "11111110", -- 7 *******
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "11000110", -- b **   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x42
           "00000000", -- 0
           "00000000", -- 1
           "11111100", -- 2 ******
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01111100", -- 6  *****
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "11111100", -- b ******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x43
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "01100110", -- 3  **  **
           "11000010", -- 4 **    *
           "11000000", -- 5 **
           "11000000", -- 6 **
           "11000000", -- 7 **
           "11000000", -- 8 **
           "11000010", -- 9 **    *
           "01100110", -- a  **  **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x44
           "00000000", -- 0
           "00000000", -- 1
           "11111000", -- 2 *****
           "01101100", -- 3  ** **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01100110", -- 6  **  **
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01101100", -- a  ** **
           "11111000", -- b *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x45
           "00000000", -- 0
           "00000000", -- 1
           "11111110", -- 2 *******
           "01100110", -- 3  **  **
           "01100010", -- 4  **   *
           "01101000", -- 5  ** *
           "01111000", -- 6  ****
           "01101000", -- 7  ** *
           "01100000", -- 8  **
           "01100010", -- 9  **   *
           "01100110", -- a  **  **
           "11111110", -- b *******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x46
           "00000000", -- 0
           "00000000", -- 1
           "11111110", -- 2 *******
           "01100110", -- 3  **  **
           "01100010", -- 4  **   *
           "01101000", -- 5  ** *
           "01111000", -- 6  ****
           "01101000", -- 7  ** *
           "01100000", -- 8  **
           "01100000", -- 9  **
           "01100000", -- a  **
           "11110000", -- b ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x47
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "01100110", -- 3  **  **
           "11000010", -- 4 **    *
           "11000000", -- 5 **
           "11000000", -- 6 **
           "11011110", -- 7 ** ****
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "01100110", -- a  **  **
           "00111010", -- b   *** *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x48
           "00000000", -- 0
           "00000000", -- 1
           "11000110", -- 2 **   **
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "11111110", -- 6 *******
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "11000110", -- b **   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x49
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4a
           "00000000", -- 0
           "00000000", -- 1
           "00011110", -- 2    ****
           "00001100", -- 3     **
           "00001100", -- 4     **
           "00001100", -- 5     **
           "00001100", -- 6     **
           "00001100", -- 7     **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01111000", -- b  ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4b
           "00000000", -- 0
           "00000000", -- 1
           "11100110", -- 2 ***  **
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01101100", -- 5  ** **
           "01111000", -- 6  ****
           "01111000", -- 7  ****
           "01101100", -- 8  ** **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "11100110", -- b ***  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4c
           "00000000", -- 0
           "00000000", -- 1
           "11110000", -- 2 ****
           "01100000", -- 3  **
           "01100000", -- 4  **
           "01100000", -- 5  **
           "01100000", -- 6  **
           "01100000", -- 7  **
           "01100000", -- 8  **
           "01100010", -- 9  **   *
           "01100110", -- a  **  **
           "11111110", -- b *******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4d
           "00000000", -- 0
           "00000000", -- 1
           "11000011", -- 2 **    **
           "11100111", -- 3 ***  ***
           "11111111", -- 4 ********
           "11111111", -- 5 ********
           "11011011", -- 6 ** ** **
           "11000011", -- 7 **    **
           "11000011", -- 8 **    **
           "11000011", -- 9 **    **
           "11000011", -- a **    **
           "11000011", -- b **    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4e
           "00000000", -- 0
           "00000000", -- 1
           "11000110", -- 2 **   **
           "11100110", -- 3 ***  **
           "11110110", -- 4 **** **
           "11111110", -- 5 *******
           "11011110", -- 6 ** ****
           "11001110", -- 7 **  ***
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "11000110", -- b **   **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x4f
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x50
           "00000000", -- 0
           "00000000", -- 1
           "11111100", -- 2 ******
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01111100", -- 6  *****
           "01100000", -- 7  **
           "01100000", -- 8  **
           "01100000", -- 9  **
           "01100000", -- a  **
           "11110000", -- b ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x510
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11010110", -- 9 ** * **
           "11011110", -- a ** ****
           "01111100", -- b  *****
           "00001100", -- c     **
           "00001110", -- d     ***
           "00000000", -- e
           "00000000", -- f
           -- code x52
           "00000000", -- 0
           "00000000", -- 1
           "11111100", -- 2 ******
           "01100110", -- 3  **  **
           "01100110", -- 4  **  **
           "01100110", -- 5  **  **
           "01111100", -- 6  *****
           "01101100", -- 7  ** **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "11100110", -- b ***  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x53
           "00000000", -- 0
           "00000000", -- 1
           "01111100", -- 2  *****
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "01100000", -- 5  **
           "00111000", -- 6   ***
           "00001100", -- 7     **
           "00000110", -- 8      **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x54
           "00000000", -- 0
           "00000000", -- 1
           "11111111", -- 2 ********
           "11011011", -- 3 ** ** **
           "10011001", -- 4 *  **  *
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x55
           "00000000", -- 0
           "00000000", -- 1
           "11000110", -- 2 **   **
           "11000110", -- 3 **   **
           "11000110", -- 4 **   **
           "11000110", -- 5 **   **
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x56
           "00000000", -- 0
           "00000000", -- 1
           "11000011", -- 2 **    **
           "11000011", -- 3 **    **
           "11000011", -- 4 **    **
           "11000011", -- 5 **    **
           "11000011", -- 6 **    **
           "11000011", -- 7 **    **
           "11000011", -- 8 **    **
           "01100110", -- 9  **  **
           "00111100", -- a   ****
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x57
           "00000000", -- 0
           "00000000", -- 1
           "11000011", -- 2 **    **
           "11000011", -- 3 **    **
           "11000011", -- 4 **    **
           "11000011", -- 5 **    **
           "11000011", -- 6 **    **
           "11011011", -- 7 ** ** **
           "11011011", -- 8 ** ** **
           "11111111", -- 9 ********
           "01100110", -- a  **  **
           "01100110", -- b  **  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
        
           -- code x58
           "00000000", -- 0
           "00000000", -- 1
           "11000011", -- 2 **    **
           "11000011", -- 3 **    **
           "01100110", -- 4  **  **
           "00111100", -- 5   ****
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00111100", -- 8   ****
           "01100110", -- 9  **  **
           "11000011", -- a **    **
           "11000011", -- b **    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x59
           "00000000", -- 0
           "00000000", -- 1
           "11000011", -- 2 **    **
           "11000011", -- 3 **    **
           "11000011", -- 4 **    **
           "01100110", -- 5  **  **
           "00111100", -- 6   ****
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5a
           "00000000", -- 0
           "00000000", -- 1
           "11111111", -- 2 ********
           "11000011", -- 3 **    **
           "10000110", -- 4 *    **
           "00001100", -- 5     **
           "00011000", -- 6    **
           "00110000", -- 7   **
           "01100000", -- 8  **
           "11000001", -- 9 **     *
           "11000011", -- a **    **
           "11111111", -- b ********
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5b
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "00110000", -- 3   **
           "00110000", -- 4   **
           "00110000", -- 5   **
           "00110000", -- 6   **
           "00110000", -- 7   **
           "00110000", -- 8   **
           "00110000", -- 9   **
           "00110000", -- a   **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5c
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "10000000", -- 3 *
           "11000000", -- 4 **
           "11100000", -- 5 ***
           "01110000", -- 6  ***
           "00111000", -- 7   ***
           "00011100", -- 8    ***
           "00001110", -- 9     ***
           "00000110", -- a      **
           "00000010", -- b       *
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5d
           "00000000", -- 0
           "00000000", -- 1
           "00111100", -- 2   ****
           "00001100", -- 3     **
           "00001100", -- 4     **
           "00001100", -- 5     **
           "00001100", -- 6     **
           "00001100", -- 7     **
           "00001100", -- 8     **
           "00001100", -- 9     **
           "00001100", -- a     **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5e
           "00010000", -- 0    *
           "00111000", -- 1   ***
           "01101100", -- 2  ** **
           "11000110", -- 3 **   **
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x5f
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "11111111", -- d ********
           "00000000", -- e
           "00000000", -- f
           -- code x60
           "00110000", -- 0   **
           "00110000", -- 1   **
           "00011000", -- 2    **
           "00000000", -- 3
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x61
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111000", -- 5  ****
           "00001100", -- 6     **
           "01111100", -- 7  *****
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01110110", -- b  *** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x62
           "00000000", -- 0
           "00000000", -- 1
           "11100000", -- 2  ***
           "01100000", -- 3   **
           "01100000", -- 4   **
           "01111000", -- 5   ****
           "01101100", -- 6   ** **
           "01100110", -- 7   **  **
           "01100110", -- 8   **  **
           "01100110", -- 9   **  **
           "01100110", -- a   **  **
           "01111100", -- b   *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x63
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111100", -- 5  *****
           "11000110", -- 6 **   **
           "11000000", -- 7 **
           "11000000", -- 8 **
           "11000000", -- 9 **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x64
           "00000000", -- 0
           "00000000", -- 1
           "00011100", -- 2    ***
           "00001100", -- 3     **
           "00001100", -- 4     **
           "00111100", -- 5   ****
           "01101100", -- 6  ** **
           "11001100", -- 7 **  **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01110110", -- b  *** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x65
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111100", -- 5  *****
           "11000110", -- 6 **   **
           "11111110", -- 7 *******
           "11000000", -- 8 **
           "11000000", -- 9 **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x66
           "00000000", -- 0
           "00000000", -- 1
           "00111000", -- 2   ***
           "01101100", -- 3  ** **
           "01100100", -- 4  **  *
           "01100000", -- 5  **
           "11110000", -- 6 ****
           "01100000", -- 7  **
           "01100000", -- 8  **
           "01100000", -- 9  **
           "01100000", -- a  **
           "11110000", -- b ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x67
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01110110", -- 5  *** **
           "11001100", -- 6 **  **
           "11001100", -- 7 **  **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01111100", -- b  *****
           "00001100", -- c     **
           "11001100", -- d **  **
           "01111000", -- e  ****
           "00000000", -- f
           -- code x68
           "00000000", -- 0
           "00000000", -- 1
           "11100000", -- 2 ***
           "01100000", -- 3  **
           "01100000", -- 4  **
           "01101100", -- 5  ** **
           "01110110", -- 6  *** **
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "11100110", -- b ***  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x69
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00011000", -- 3    **
           "00000000", -- 4
           "00111000", -- 5   ***
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x6a
           "00000000", -- 0
           "00000000", -- 1
           "00000110", -- 2      **
           "00000110", -- 3      **
           "00000000", -- 4
           "00001110", -- 5     ***
           "00000110", -- 6      **
           "00000110", -- 7      **
           "00000110", -- 8      **
           "00000110", -- 9      **
           "00000110", -- a      **
           "00000110", -- b      **
           "01100110", -- c  **  **
           "01100110", -- d  **  **
           "00111100", -- e   ****
           "00000000", -- f
           -- code x6b
           "00000000", -- 0
           "00000000", -- 1
           "11100000", -- 2 ***
           "01100000", -- 3  **
           "01100000", -- 4  **
           "01100110", -- 5  **  **
           "01101100", -- 6  ** **
           "01111000", -- 7  ****
           "01111000", -- 8  ****
           "01101100", -- 9  ** **
           "01100110", -- a  **  **
           "11100110", -- b ***  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x6c
           "00000000", -- 0
           "00000000", -- 1
           "00111000", -- 2   ***
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00011000", -- 6    **
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00111100", -- b   ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x6d
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11100110", -- 5 ***  **
           "11111111", -- 6 ********
           "11011011", -- 7 ** ** **
           "11011011", -- 8 ** ** **
           "11011011", -- 9 ** ** **
           "11011011", -- a ** ** **
           "11011011", -- b ** ** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x6e
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11011100", -- 5 ** ***
           "01100110", -- 6  **  **
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "01100110", -- b  **  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x6f
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111100", -- 5  *****
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x70
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11011100", -- 5 ** ***
           "01100110", -- 6  **  **
           "01100110", -- 7  **  **
           "01100110", -- 8  **  **
           "01100110", -- 9  **  **
           "01100110", -- a  **  **
           "01111100", -- b  *****
           "01100000", -- c  **
           "01100000", -- d  **
           "11110000", -- e ****
           "00000000", -- f
           -- code x71
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01110110", -- 5  *** **
           "11001100", -- 6 **  **
           "11001100", -- 7 **  **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01111100", -- b  *****
           "00001100", -- c     **
           "00001100", -- d     **
           "00011110", -- e    ****
           "00000000", -- f
           -- code x72
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11011100", -- 5 ** ***
           "01110110", -- 6  *** **
           "01100110", -- 7  **  **
           "01100000", -- 8  **
           "01100000", -- 9  **
           "01100000", -- a  **
           "11110000", -- b ****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x73
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "01111100", -- 5  *****
           "11000110", -- 6 **   **
           "01100000", -- 7  **
           "00111000", -- 8   ***
           "00001100", -- 9     **
           "11000110", -- a **   **
           "01111100", -- b  *****
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x74
           "00000000", -- 0
           "00000000", -- 1
           "00010000", -- 2    *
           "00110000", -- 3   **
           "00110000", -- 4   **
           "11111100", -- 5 ******
           "00110000", -- 6   **
           "00110000", -- 7   **
           "00110000", -- 8   **
           "00110000", -- 9   **
           "00110110", -- a   ** **
           "00011100", -- b    ***
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x75
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11001100", -- 5 **  **
           "11001100", -- 6 **  **
           "11001100", -- 7 **  **
           "11001100", -- 8 **  **
           "11001100", -- 9 **  **
           "11001100", -- a **  **
           "01110110", -- b  *** **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x76
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11000011", -- 5 **    **
           "11000011", -- 6 **    **
           "11000011", -- 7 **    **
           "11000011", -- 8 **    **
           "01100110", -- 9  **  **
           "00111100", -- a   ****
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x77
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11000011", -- 5 **    **
           "11000011", -- 6 **    **
           "11000011", -- 7 **    **
           "11011011", -- 8 ** ** **
           "11011011", -- 9 ** ** **
           "11111111", -- a ********
           "01100110", -- b  **  **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x78
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11000011", -- 5 **    **
           "01100110", -- 6  **  **
           "00111100", -- 7   ****
           "00011000", -- 8    **
           "00111100", -- 9   ****
           "01100110", -- a  **  **
           "11000011", -- b **    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x79
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11000110", -- 5 **   **
           "11000110", -- 6 **   **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11000110", -- a **   **
           "01111110", -- b  ******
           "00000110", -- c      **
           "00001100", -- d     **
           "11111000", -- e *****
           "00000000", -- f
           -- code x7a
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00000000", -- 4
           "11111110", -- 5 *******
           "11001100", -- 6 **  **
           "00011000", -- 7    **
           "00110000", -- 8   **
           "01100000", -- 9  **
           "11000110", -- a **   **
           "11111110", -- b *******
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x7b {
           "00000000", -- 0
           "00000000", -- 1
           "00001110", -- 2     ***
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "01110000", -- 6  ***
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00001110", -- b     ***
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x7c |
           "00000000", -- 0
           "00000000", -- 1
           "00011000", -- 2    **
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00000000", -- 6
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "00011000", -- b    **
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x7d }
           "00000000", -- 0
           "00000000", -- 1
           "01110000", -- 2  ***
           "00011000", -- 3    **
           "00011000", -- 4    **
           "00011000", -- 5    **
           "00001110", -- 6     ***
           "00011000", -- 7    **
           "00011000", -- 8    **
           "00011000", -- 9    **
           "00011000", -- a    **
           "01110000", -- b  ***
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x7e ~
           "00000000", -- 0
           "00000000", -- 1
           "01110110", -- 2  *** **
           "11011100", -- 3 ** ***
           "00000000", -- 4
           "00000000", -- 5
           "00000000", -- 6
           "00000000", -- 7
           "00000000", -- 8
           "00000000", -- 9
           "00000000", -- a
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000", -- f
           -- code x7f
           "00000000", -- 0
           "00000000", -- 1
           "00000000", -- 2
           "00000000", -- 3
           "00010000", -- 4    *
           "00111000", -- 5   ***
           "01101100", -- 6  ** **
           "11000110", -- 7 **   **
           "11000110", -- 8 **   **
           "11000110", -- 9 **   **
           "11111110", -- a *******
           "00000000", -- b
           "00000000", -- c
           "00000000", -- d
           "00000000", -- e
           "00000000"  -- f
           );
        begin
            --return X <= 8 and Y <= 16 and ROM((char * 16) + Y)(9 - X) = '1';
            return ROM((CHARACTER'POS(char) * 16) + Y)(9 - X) = '1';
        end draw_char;
        
  
        
        function draw_string(scanX : natural; scanY : natural; posX : natural; posY : natural; s : string; center : boolean; size : natural) return boolean is
            constant charW : natural := 8 * size;
            constant charWsp : natural := charW + 2;
            constant charH : natural := 16 * size;
            constant width : natural := charWsp * s'LENGTH;
            constant height : natural := charH;
            variable x : natural := posX;
            variable y : natural := posY;
            variable char : natural;
            variable subX : natural;
            begin
                if (center) then
                    x := x - (width / 2);
                    y := y - (height / 2);
                end if;
            
                if (scanX < x or scanY < y) then
                    return false;
                end if;
                
                if (scanX - x > width or scanY - y > height) then
                    return false;
                end if;
                
                x := scanX - x;
                y := scanY - y;
                
                subX := x mod charWsp;
                char := (x / charWsp) + 1;
                
                return draw_char(subX / size, y / size, s(char));
        end draw_string;
        
function to_string ( a: std_logic_vector) return string is --function to make it string hopfully works 
        variable b : string (1 to a'length) := (others => NUL);
        variable stri : integer := 1; 
        begin
            for i in a'range loop
                b(stri) := std_logic'image(a((i)))(2);
            stri := stri+1;
            end loop;
        return b;
        end function;
            
        
        
begin
    
    
	VGA: entity work.vga
        port map (
            CLK_I => clk,
            VGA_RED_O => vgaRed,
            VGA_BLUE_O => vgaBlue,
            VGA_GREEN_O => vgaGreen,
            VGA_HS_O => Hsync,
            VGA_VS_O => Vsync,
            X => X,
            Y => Y,
            R => Red,
            G => Green,
            B => Blue
        );
    

    KEY: ps2keyboard port map(
        resetn => '1',
        clock => clk,
        ps2c => ps2c,
        ps2d => ps2d,
        DOUT => DOUT,
        sXDDD => keyboard
    );
    
    CLKDIV: ClockDivider port map(
                in_clk => clk,
                outclk2 => outclk2,
                outclk3 => outclk3);	
                
	sevenSegDisplay : Multiple_7segmentDisplayWithClockDivider     
	       port map (
	            clk2 => outclk2,
	            clk3 => outclk3,
	            d0 => in0,
	            d1 => in1,
	            d2 => in2,
	            d3 => in3,
	            segs => segs,
	            dp => dp,
	            channels => channels);
	 
	 JSTK : PmodJSTK_Master port map (
	       CLK => clk,
	       RST => '0',
	       MISO => MISO,
	       SW => "000",
	       SS => SS,
	       MOSI => MOSI,
	       SCLK => SCLK,
	       LED => LED,
	       posData => joy);
	       
	--Setting the motion up or down
        process(clk, reset, joy)
        begin
            if( rising_edge(clk) ) then
                btn_cnt <= btn_cnt + 1;
                if( reset = '1' ) then --Resetting the game
                    moveUp <= '0';
                    moveDown <= '0';              
                elsif( btn_cnt >=  500000) then
                    btn_cnt <= 0;
                    if(joy <= "0100101100") then
                        moveUp <= '1';
                        moveDown <= '0';
					elsif(joy >= "1001011000") then
						moveUp <= '0';
						moveDown <= '1';
                    end if;
                end if;
            end if;
        end process;
    
     process(clk, reset, keyboard) --keyboard control for player 2 , guy2 use w and s for up and down 
               begin
                   --if( rising_edge(clk) ) then
                      -- btn_cnt2 <= btn_cnt2 + 1;
                       if( reset = '1' ) then --Resetting the game
                           moveUp2 <= '0';
                           moveDown2 <= '0';              
                       else
       
                           if(keyboard(7 downto 0) = "01110101"  ) then
                               moveUp2 <= '1';
                               moveDown2 <= '0';
                           elsif(keyboard(7 downto 0) = "01110010" ) then
                               moveUp2 <= '0';
                               moveDown2 <= '1';
                            else
                                moveUp2 <= '0';
                                moveDown2 <= '0'; 
                           end if;
                       end if;
                 --  end if;
     end process;
     
       
    
     process( clk, reset, moveUp2, moveDown2) --motion process for guy 2 
        begin
             if( rising_edge(clk) ) then
                clk_cnt2 <= clk_cnt2 + 1;
                if( reset = '1' ) then
                    posX2 <= centerX+90; --spawning the second player to the right of the first player 
                    posY2 <= centerY;
                    gameOver2 <= '0';---------------------------------------------------------------------------------------Will need to change this lol 
                elsif( clk_cnt2 >= 500000) then
                    clk_cnt2 <= 0;
                    
                    if( gameOver2 = '0' ) then --For less energy use
                        --Motion
                        if( moveUp2 = '1' and posY2 >= speedOfGuy2) then
                             posY2 <= posY2 - speedOfGuy2;
                        elsif( moveDown2 = '1' and posY2 <= 1024 - sizeOfGuy2 + speedOfGuy2) then
                            posY2 <= posY2 + speedOfGuy2;
                        end if; 
                        
                        --Collision
                        if( ( posY2 + sizeOfGuy2 >= currentUpEdge and posY2 <= currentUpEdge + heightOfBar)
                              or ( posY2 + sizeOfGuy2 >= currentDownEdge and posY2 <= currentDownEdge + heightOfBar)
                              or posY2 <= speedOfGuy2 or posY2 >= 1024 - sizeOfGuy2 ) then
                            gameOver2 <= '1';
                        end if; 
                     --elsif added for the movement of the blocks once they lose 
                     elsif(gameOver2 = '1') then
                           posY2 <= 0; 
                           posX2 <= 0; 
                    end if;
                         
                end if;
             end if;
        end process;
    
    
    
    --Motion
    process( clk, reset, moveUp, moveDown)
    begin
         if( rising_edge(clk) ) then
            clk_cnt <= clk_cnt + 1;
            if( reset = '1' ) then
                posX <= centerX;
                posY <= centerY;
                gameOver <= '0';
            elsif( clk_cnt >= 500000) then
                clk_cnt <= 0;
                
                if( gameOver = '0' ) then --For less energy use
                    --Motion
                    if( moveUp = '1' and posY >= speedOfGuy) then
                         posY <= posY - speedOfGuy;
                    elsif( moveDown = '1' and posY <= 1024 - sizeOfGuy + speedOfGuy) then
                        posY <= posY + speedOfGuy;
                    end if; 
                    
                    --Collision
                    if( ( posY + sizeOfGuy >= currentUpEdge and posY <= currentUpEdge + heightOfBar)
                          or ( posY + sizeOfGuy >= currentDownEdge and posY <= currentDownEdge + heightOfBar)
                          or posY <= speedOfGuy or posY >= 1024 - sizeOfGuy ) then
                        gameOver <= '1';
                    end if; 
                    --elsif added for the movement of the blocks once they lose 
                 elsif(gameOver = '1') then
                    posY <= 0; 
                    posX <= 0; 
                end if;
                     
            end if;
         end if;
    end process;
    
	--Mechanics for the motion of bars
	process( clk )    
	begin
	   if (rising_edge(clk)) then
           frame_count <= frame_count + 1;
           if( reset = '1') then --Resetting the game
               indexUpBarNext <= 0;
               upBarXPositions <= (1280, 1280 + upBarLengths(0), 1280 + upBarLengths(0) + upBarLengths(1),
                                   1280 + upBarLengths(0) + upBarLengths(1) + upBarLengths(2),
                                   1280 + upBarLengths(0) + upBarLengths(1) + upBarLengths(2) + upBarLengths(3) );
               upBarYPositions <= (350,300,250,200,250);
               upBarLengths <= ( 256,256, 256, 256,256);
               
               indexDownBarNext <= 0;
               downBarXPositions <= (centerX, centerX + downBarLengths(0), centerX + downBarLengths(0) + downBarLengths(1),
                                     centerX + downBarLengths(0) + downBarLengths(1) + downBarLengths(2),
                                     centerX + downBarLengths(0) + downBarLengths(1) + downBarLengths(2) + downBarLengths(3) );
               downBarYPositions <= (700, 580, 610, 640,640);
               downBarLengths <= ( 256,256,256,256,256);
           elsif (frame_count >= 500000) then
               frame_count <= 0;
               if( gameOver = '0') then ---may need to change -------------------------added gameOver2 as well
                   for i in 0 to 4 loop
                      upBarXPositions(i) <= upBarXPositions(i) - speedOfBars;
                      downBarXPositions(i) <= downBarXPositions(i) - speedOfBars;
                      if( upBarXPositions(i) + upBarLengths(i) <= 0) then
                          --Up Bars
                          upBarXPositions(i) <= 1280;
                          upBarLengths(i) <= upBarLengthsNext( indexUpBarNext);
                          upBarYPositions(i) <= upBarYPositionsNext( indexUpBarNext);
                          if( indexUpBarNext >= 99) then
                               indexUpBarNext <= 0;
                          else
                               indexUpBarNext <= indexUpBarNext + 1;
                          end if;
                       end if;
                           
                       if ( downBarXPositions(i) + downBarLengths(i) <= 0) then
                         --Down Bars
                         downBarXPositions(i) <= 1280;
                         downBarLengths(i) <= downBarLengthsNext( indexDownBarNext);
                         downBarYPositions(i) <= downBarYPositionsNext( indexDownBarNext);
                         if( indexDownBarNext >= 99) then
                             indexDownBarNext <= 0;
                         else
                             indexDownBarNext <= indexDownBarNext + 1;
                         end if;
                         
                      end if;
                    end loop;
                    elsif(gameOver2 = '0') then
                   for i in 0 to 4 loop
                        upBarXPositions(i) <= upBarXPositions(i) - speedOfBars;
                         downBarXPositions(i) <= downBarXPositions(i) - speedOfBars;
                          if( upBarXPositions(i) + upBarLengths(i) <= 0) then
                                             --Up Bars
                                             upBarXPositions(i) <= 1280;
                                             upBarLengths(i) <= upBarLengthsNext( indexUpBarNext);
                                             upBarYPositions(i) <= upBarYPositionsNext( indexUpBarNext);
                                             if( indexUpBarNext >= 99) then
                                                  indexUpBarNext <= 0;
                                             else
                                                  indexUpBarNext <= indexUpBarNext + 1;
                                             end if;
                                          end if;
                                              
                                          if ( downBarXPositions(i) + downBarLengths(i) <= 0) then
                                            --Down Bars
                                            downBarXPositions(i) <= 1280;
                                            downBarLengths(i) <= downBarLengthsNext( indexDownBarNext);
                                            downBarYPositions(i) <= downBarYPositionsNext( indexDownBarNext);
                                            if( indexDownBarNext >= 99) then
                                                indexDownBarNext <= 0;
                                            else
                                                indexDownBarNext <= indexDownBarNext + 1;
                                            end if;
                                            
                                         end if;
                                       end loop;
               end if;
               
           end if;
       end if;
	end process;
	
	--Mechanis for current edge of up bar, no need to divide clk or clk in sensivity list since upBarXPositions change
	-- with the rate of the frame
	process( clk, upBarXPositions, posX, posX2, gameOver2, gameOver, upBarLengths, upBarYPositions)
	begin
	   if (rising_edge(clk)) then
	       curUp_cnt <= curUp_cnt + 1;
	        curUp_cnt2 <= curUp_cnt2 + 1;
	       if( reset = '1') then
	           curUp_cnt <= 0;
	           curUp_cnt2 <= 0;
	       elsif( curUp_cnt >= 900 AND curUp_cnt2 >= 900) then
	           curUp_cnt <= 0;
	           curUp_cnt2 <= 0;
	           if( gameOver = '0' ) then
                  for i in 0 to 4 loop
                     if( posX + sizeOfGuy >= upBarXPositions(i) and posX <= upBarXPositions(i) + upBarLengths(i) - sizeOfGuy  ) then
                         currentUpEdge <= upBarYPositions(i);
                         exit;
                     else
                         currentUpEdge <= 0;    
                     end if;
                  end loop;
               elsif( gameOver2 = '0' ) then
                  for i in 0 to 4 loop
                     if(  posX2 + sizeOfGuy2 >= upBarXPositions(i) and posX2 <= upBarXPositions(i) + upBarLengths(i) - sizeOfGuy2 ) then
                         currentUpEdge <= upBarYPositions(i);
                        exit;
                     else
                        currentUpEdge <= 0;    
                     end if;
                  end loop;
              end if; 
	       end if;
	   end if; 
	end process;
	
	
	
	--Mechanis for current edge of down bar, no need to divide clk or clk in sensivity list since upBarXPositions change
    -- with the rate of the frame
	process( clk, downBarXPositions, posX,posX2, gameOVer2, gameOVer, downBarLengths, downBarYPositions)
    begin
        if( rising_edge(clk) ) then
            curDown_cnt <= curDown_cnt + 1;
            curDown_cnt2 <= curDown_cnt2 + 1;
            if( reset = '1') then
                curDown_cnt <= 0;
                curDown_cnt2 <= 0;
            elsif( curDown_cnt >= 900 AND curDown_cnt2 >= 900) then
                curDown_cnt <= 0;
                curDown_cnt2 <= 0;
                if( gameOver = '0' ) then
                    for i in 0 to 4 loop
                       if( posX + sizeOfGuy >= downBarXPositions(i)  and posX <= downBarXPositions(i) + downBarLengths(i) - sizeOfGuy  ) then
                           currentDownEdge <= downBarYPositions(i);
                           exit;
                       else
                           currentDownEdge <= 1024;    
                       end if;
                   end loop;
                   
                   elsif( gameOver2 = '0') then
                       for i in 0 to 4 loop
                          if( posX2 + sizeOfGuy2 >= downBarXPositions(i)  and posX2 <= downBarXPositions(i) + downBarLengths(i) - sizeOfGuy2 ) then
                              currentDownEdge <= downBarYPositions(i);
                             exit;
                          else
                              currentDownEdge <= 1024;    
                          end if;
                        end loop;
                   
                                
                end if; 
            end if;
        end if;
    end process;
    
	
	--Timer for score for player 1
	process( clk)
	begin
        if( rising_edge(clk) ) then
            score_cnt <= score_cnt + 1;
            if( reset = '1') then
                score_cnt <= 0;
                score <= 0;
               -- score3 <= (others=>'0');
            elsif( score_cnt >= 10000000) then
                score_cnt <= 0;
                if( gameOver = '0' ) then
                    score <= score + 1;
                   -- score3 <= (others=>'0');
                end if;
            end if;
        end if;
	end process;
	
	process( clk) --score2 for the second player process
        begin
            if( rising_edge(clk) ) then
                score_cnt2 <= score_cnt2 + 1;
                if( reset = '1') then
                    score_cnt2 <= 0;
                    score2 <= 0;
                    
                   -- score3 <= (others=>'0'); --as logic vector 
                elsif( score_cnt2 >= 10000000) then
                    score_cnt2 <= 0;
                    if( gameOver2 = '0' ) then
                        score2 <= score2 + 1;
                       -- score3 <= score3 + 1; 
                     elsif(gameOver2 = '1')  then
                        score2Final <= score2;  --making the score a final score if game over . 
                    end if;
                end if;
            end if;
        end process;
	
	
	
	--Showing the socre on 7 segment display
	process( score)
	variable integer0: natural range 0 to 9;
	variable integer1: natural range 0 to 9;
	variable integer1mod: natural range 0 to 99;
	variable integer2: natural range 0 to 9;
	variable integer2mod: natural range 0 to 999;
	variable integer3: natural range 0 to 9;
	begin
	   integer0 := score mod 10;
	   in0 <=  conv_std_logic_vector(integer0,4);
	   
	   integer1mod := score mod 100;
	   integer1 := integer1Mod / 10;
	   in1 <= conv_std_logic_vector(integer1,4);
	   
	   integer2mod := score mod 1000;
	   integer2 := integer2mod / 100;
	   in2 <= conv_std_logic_vector(integer2,4);
	   
	   integer3 := score / 1000;
	   in3 <= conv_std_logic_vector(integer3,4);
	end process;
	
	--Adjusting the speed according to score
	process(clk, speed, gameOver, gameOver2)
	begin
	   if( rising_edge(clk) ) then
	      if( reset = '1' ) then
              speedOfGuy <= 1;
              speedOfGuy2 <= 1;
              speedOfBars <= 1;
--          elsif ( score <= 100) then --Defensive Strategy
--              speedOfGuy <= 1;
--              speedOfBars <= 1;
          elsif(speed(3) = '1') then
              speedOfBars <= 5;
          elsif(speed(2) = '1') then
              speedOfBars <= 4;
              speedOfGuy <= 4;
              speedOfGuy2 <= 4;
          elsif(speed(1) = '1') then
              speedOfGuy <= 3;
              speedOfGuy2 <= 3;
              speedOfBars <= 3;
          elsif(speed(0) = '1') then
              speedOfGuy <= 2;
              speedOfGuy2 <= 2;
              speedOfBars <= 2;
              
          else
              speedOfGuy <= 1;
              speedOfGuy2 <= 1;
              speedOfBars <= 1;
          end if;
	   end if;
	end process;
	
	

	--Drawing the video
	process( X, Y, gameOver,gameOver2, score, scoreFinal, score2Final, score2, PlayerColor, posX, posY, upBarXPositions, upBarYPositions, upBarLengths, downBarYPositions, downBarXPositions, downBarLengths)
	begin
	    if( gameOver = '1' AND gameOver2 = '1' ) then
	       if (draw_string(X, Y, centerX, centerY-300, "Gameover", true, 5)) then
	           Red <= 15;
               Green <= 15;
               Blue <= 0;
               elsif(draw_string(X, Y, centerX-70, centerY-200, "Player 1 Score: ", true, 2)) then --display the score at the end of the game 
                 Red <= 15;
                 Green <= 15;
                 Blue <= 0;
               elsif(draw_string(X, Y, centerX-70, centerY-100, "Player 2 Score: ", true, 2)) then --display the score at the end of the game 
                 Red <= 15;
                 Green <= 15;
                 Blue <= 0;
              elsif(draw_string(X, Y, centerX+250, centerY-200,int_to_str(score) , true, 2)) then --display the score at the end of the game 
                        Red <= 15;
                        Green <= 15;
                        Blue <= 0;
              elsif(draw_string(X, Y, centerX+250, centerY-100,int_to_str(score2) , true, 2)) then --display the score at the end of the game 
                        Red <= 15;
                        Green <= 15;
                        Blue <= 0;
             elsif(draw_string(X, Y, centerX, centerY, "Press middle push button to play again ", true, 2)) then --display the score at the end of the game 
                        Red <= 15;
                        Green <= 15;
                        Blue <= 0;
                        
                        
                         -- signal X : natural range 0 to 1280;
                         -- signal Y : natural range 0 to 1024;
--             elsif(Y > 990 and Y < 1024 and X > 0 and X < 1280 ) then --This is the bottom boarder of the game 
--                        Red <= 15;
--                        Green <= 0;
--                        Blue <= 0;   


--             elsif(Y > 0 and Y < 1024 and X > 0 and X < 34 ) then --This is the bottom boarder of the game 
--                        Red <= 15;
--                        Green <= 0;
--                        Blue <= 0;    
--             elsif(Y > 0 and Y < 34 and X > 0 and X < 1280 ) then --This is the bottom boarder of the game 
--                        Red <= 15;
--                        Green <= 0;
--                        Blue <= 0;                                    
--              elsif(Y > 0 and Y < 1024 and X > 1246 and X < 1280 ) then --This is the bottom boarder of the game 
--                        Red <= 15;
--                        Green <= 0;
--                        Blue <= 0; 
	       else
	           Red <= 0;
	           Green <= 0;
	           Blue <= 0;
	       end if;
	    else
	           --guy 2 
	          
	       --Guy
            if( Y > posY and Y < posY + sizeOfGuy and X > posX and X < posX + sizeOfGuy ) then
                    if( gameOver = '1') then
                    Red <= 0;
                    Green <= 0; --turns black after it touches the wall
                    Blue <= 0;
                   -- sizeOfGuy <= sizeOfGuy-50; 
                   --speedOfGuy <= 0; 
                    
                    
                     elsif( PlayerColor(0) = '1' and Y > posY and Y < posY +sizeOfGuy   and X > posX and X < (posX + sizeOfGuy) ) then 
                                              
                        if( gameOver = '1') then
                            Red <= 0;
                            Green <= 0;
                            Blue <= 0;
                           -- sizeOfGuy <= sizeOfGuy-50;
                          -- speedOfGuy <= 0;                                            
                        else
                                    
                           Red <= 0; 
                           Green <= 15; 
                           Blue <= 0; 
                                      
                       end if;
                     elsif( PlayerColor(1) = '1' and Y > posY and Y < posY + sizeOfGuy and X > posX and X < posX + sizeOfGuy) then 
                                                                     
                        if( gameOver = '1') then
                           Red <= 0;
                           Green <= 0;
                           Blue <= 0;
                          -- sizeOfGuy <= sizeOfGuy-50;
                          --speedOfGuy <= 0;                                                                         
                        else
                           Red <= 0;
                           Green <= 0;
                           Blue <= 15;
                        end if;
                                                                
                    elsif( PlayerColor(2) = '1' and Y > posY and Y < posY + sizeOfGuy and X > posX and X < posX + sizeOfGuy) then 
                                                                                                        
                        if( gameOver = '1') then
                           Red <= 0;
                           Green <= 0;
                           Blue <= 0;
                           --sizeOfGuy <= sizeOfGuy-50; --make the guy dissappear
                           --speedOfGuy <= 0;                                                                                                             
                        else
                           Red <= 0;
                           Green <= 15;
                           Blue <= 15;
                       end if;
                    else
                    
                    Red <= 15;
                    Green <= 0;
                    Blue <= 0;
                    end if;
            
            elsif( Y > posY2 and Y < posY2 + sizeOfGuy2 and X > posX2 and X < posX2 + sizeOfGuy2 ) then --here is the guy 2 drawing and their color switch 
                      if( gameOver2 = '1') then
                       Red <= 0; --turns black as soon as it hits the wall
                       Green <= 0;
                       Blue <= 0;
                       --sizeOfGuy2 <= sizeOfGuy2-50;
                      -- speedOfGuy2 <= 0;                      
                       elsif( PlayerColor(3) = '1' and Y > posY2 and Y < posY2 +sizeOfGuy2   and X > posX2 and X < (posX2 + sizeOfGuy2) ) then 
                                                                                           
                             if( gameOver2 = '1') then
                                      Red <= 0;
                                      Green <= 0;
                                      Blue <= 0;
                                     --sizeOfGuy2 <= sizeOfGuy2-50;
                                    -- speedOfGuy2 <= 0; 
                                                                                                                    
                             else
                                                                                 
                                      Red <= 15; 
                                      Green <= 15; 
                                      Blue <= 0; 
                                                                                   
                            end if;
                       elsif( PlayerColor(4) = '1' and Y > posY2 and Y < posY2 + sizeOfGuy2 and X > posX2 and X < posX2 + sizeOfGuy2) then 
                                                                                                                  
                            if( gameOver2 = '1') then --turns black
                                      Red <= 0;
                                      Green <= 0;
                                      Blue <= 0;
                                     --sizeOfGuy2 <= sizeOfGuy2-50;
                                    -- speedOfGuy2 <= 0;                                                                                                             
                            else
                                      Red <= 15;
                                      Green <= 0;
                                      Blue <= 15; 
                           end if;
                                                                                                             
                       elsif( PlayerColor(5) = '1' and Y > posY2 and Y < posY2 + sizeOfGuy2 and X > posX2 and X < posX2 + sizeOfGuy2) then 
                                                                                                                                                     
                           if( gameOver2 = '1') then --turns black 
                                     Red <= 0;
                                     Green <= 0;
                                     Blue <= 0;
                                     --sizeOfGuy2 <= sizeOfGuy2-50;
                                    -- speedOfGuy2 <= 0;                                                                                                                                                
                              else
                                     Red <= 15;
                                     Green <= 15;
                                     Blue <= 15;
                              end if;
                 else
                                                                                                 
                   Red <= 0; 
                   Green <= 15; 
                   Blue <= 0; 
               end if; 
             elsif(draw_string(X, Y, centerX, centerY-450, "Hakuna Matata 2 player ", true, 2)) then 
                   Red <= 0;
                   Green <= 0;
                   Blue <= 15;   
            elsif(draw_string(X, Y, centerX-200, centerY-400, "Player 1 Score: ", true, 2)) then 
                   Red <= 15;
                   Green <= 0;
                   Blue <= 0;   
                                                             
                                            
            elsif(draw_string(X, Y, centerX+50, centerY-400,  int_to_str(score) , true, 2)) then 
                  Red <= 15;
                  Green <= 0;
                  Blue <= 0;   
                                 
           elsif(draw_string(X, Y, centerX+250, centerY-400, "Player 2 Score: ", true, 2)) then 
                 Red <= 0;
                 Green <= 15;
                 Blue <= 0;   
            elsif(draw_string(X, Y, centerX+500, centerY-400,int_to_str(score2) , true, 2)) then --change score to score2 once it's implemented
                 Red <= 0;
                 Green <= 15;
                 Blue <= 0;   
--           elsif(Y > 1004 and Y < 1024 and X > 0 and X < 1280 ) then --This is the bottom boarder of the game 
--                                        Red <= 15;
--                                        Green <= 0;
--                                        Blue <= 0;   
                
                
--           elsif(Y > 0 and Y < 1024 and X > 0 and X < 20 ) then --This is the bottom boarder of the game 
--                                        Red <= 15;
--                                        Green <= 0;
--                                        Blue <= 0;    
--           elsif(Y > 0 and Y < 20 and X > 0 and X < 1280 ) then --This is the bottom boarder of the game 
--                                        Red <= 15;
--                                        Green <= 0;
--                                        Blue <= 0;                                    
--            elsif(Y > 0 and Y < 1024 and X > 1260 and X < 1280 ) then --This is the bottom boarder of the game 
--                                        Red <= 15;
--                                        Green <= 0;
--                                        Blue <= 0; 
                           
            elsif( Y > upBarYPositions(0) and Y < upBarYPositions(0) + heightOfBar
                                   and  X > upBarXPositions(0)
                                   and X < upBarXPositions(0) + upBarLengths(0)) then
                Red <= 0;
                Green <= 15;
                Blue <= 0;
            elsif( Y > upBarYPositions(1) and Y < upBarYPositions(1) + heightOfBar
                                   and  X > upBarXPositions(1)
                                   and X < upBarXPositions(1) + upBarLengths(1) ) then
                Red <= 0;
                Green <= 15;
                Blue <= 0;
                            
            elsif( Y > upBarYPositions(2) and Y < upBarYPositions(2) + heightOfBar
                                   and  X > upBarXPositions(2) 
                                   and X < upBarXPositions(2) + upBarLengths(2) ) then
                Red <= 0;
                Green <= 15;
                Blue <= 0;
                                        
            elsif( Y > upBarYPositions(3) and Y < upBarYPositions(3) + heightOfBar
                                   and  X > upBarXPositions(3)
                                   and X < upBarXPositions(3) + upBarLengths(3) ) then
                Red <= 0;
                Green <= 15;
                Blue <= 0;
            elsif( Y > upBarYPositions(4) and Y < upBarYPositions(4) + heightOfBar
                                   and  X > upBarXPositions(4)
                                   and X < upBarXPositions(4) + upBarLengths(4) ) then
                Red <= 0;
                Green <= 15;
                Blue <= 0;
            
            elsif( Y > downBarYPositions(0) and Y < downBarYPositions(0) + heightOfBar
                                   and  X > downBarXPositions(0)
                                   and X < downBarXPositions(0) + downBarLengths(0)) then
                Red <= 0;
                Green <= 0;
                Blue <= 15;
            elsif( Y > downBarYPositions(1) and Y < downBarYPositions(1) + heightOfBar
                                   and  X > downBarXPositions(1)
                                   and X < downBarXPositions(1) + downBarLengths(1) ) then
                Red <= 0;
                Green <= 0;
                Blue <= 15;
                            
            elsif( Y > downBarYPositions(2) and Y < downBarYPositions(2) + heightOfBar
                                   and  X > downBarXPositions(2) 
                                   and X < downBarXPositions(2) + downBarLengths(2) ) then
                Red <= 0;
                Green <= 0;
                Blue <= 15;
                                        
            elsif( Y > downBarYPositions(3) and Y < downBarYPositions(3) + heightOfBar
                                   and  X > downBarXPositions(3)
                                   and X < downBarXPositions(3) + downBarLengths(3) ) then
                Red <= 0;
                Green <= 0;
                Blue <= 15;
            elsif( Y > downBarYPositions(4) and Y < downBarYPositions(4) + heightOfBar
                                   and  X > downBarXPositions(4)
                                   and X < downBarXPositions(4) + downBarLengths(4) ) then
                Red <= 0;
                Green <= 0;
                Blue <= 15;
                
            --Background
            
            else
               Red <= 0;
               Green <= 0;
               Blue <= 0;         
            end if;
	    end if;

	end process;
end Behavioral;