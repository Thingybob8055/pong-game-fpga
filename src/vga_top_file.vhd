library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_top_file is
    Port ( clk : in STD_LOGIC;
--           btn_rst_n : in STD_LOGIC;
           btn_fire : in STD_LOGIC;
           btn_up : in STD_LOGIC;
           btn_dn : in STD_LOGIC;
           vgaRed : out STD_LOGIC_VECTOR (3 downto 0);
           vgaGreen : out STD_LOGIC_VECTOR (3 downto 0);
           vgaBlue : out STD_LOGIC_VECTOR (3 downto 0);
           HS : out STD_LOGIC;
           VS : out STD_LOGIC);
end vga_top_file;

architecture Behavioral of vga_top_file is
    Signal blanking : std_logic;
    Signal pixel_clk : std_logic;
    Signal hcount   :   unsigned(10 downto 0);
    Signal vcount   :   unsigned(10 downto 0);

    constant CORDW : integer := 11;

    -- for color gradient
    Signal square : std_logic;
    Signal paint_red : STD_LOGIC_VECTOR(3 downto 0);
    Signal paint_green : STD_LOGIC_VECTOR(3 downto 0);
    Signal paint_blue : STD_LOGIC_VECTOR(3 downto 0);

    constant H_RES : integer := 640;
    constant V_RES : integer := 480;

    constant WIN : integer := 4;
    constant SPEEDUP : integer := 5;
    constant BALL_SIZE : integer := 8;
    constant BALL_ISPX : integer := 5;
    constant BALL_ISPY : integer := 3;
    constant PAD_HEIGHT : integer := 48;
    constant PAD_WIDTH : integer := 10;
    constant PAD_OFFS : integer := 32;
    constant PAD_SPY : integer := 3;

    Signal frame : std_logic;

    Signal score_l : unsigned(3 downto 0);
    Signal score_r : unsigned(3 downto 0);
    
    Signal ball, padl, padr : std_logic;

    Signal ball_x, ball_y : unsigned(CORDW-1 downto 0);
    Signal ball_spx: unsigned(CORDW-1 downto 0);
    Signal ball_spy: unsigned(CORDW-1 downto 0);
    Signal shot_cnt : unsigned(3 downto 0);
    Signal ball_dx, ball_dy : std_logic;
    Signal ball_dx_prev : std_logic;
    Signal coll_r, coll_l : std_logic;

    Signal padl_y, padr_y : unsigned(CORDW-1 downto 0);
    Signal ai_y, play_y : unsigned(CORDW-1 downto 0);

    Signal sig_fire, sig_up, sig_dn : std_logic;

    type STATE_TYPE is (NEW_GAME, POSITION, READY, POINT, END_GAME, PLAY);
    Signal state, state_next: STATE_TYPE;

    Signal pix_score : std_logic;
begin

    vga_controller : entity work.vga_controller_640_60(Behavioral)
        Port map (rst => '0', pixel_clk => pixel_clk, HS => HS, VS => VS, hcount => hcount, vcount => vcount, blank => blanking);

    clk_div_unit_1hz : entity work.nbit_clk_div(Behavioral)
        Generic map (div_factor => 4,
                     high_count => 2,
                     num_of_bits => 3)
        Port map (clk_in => clk, output => pixel_clk);

    frame <= '1' when (vcount = V_RES and hcount = 0) else '0';

    padl_y <= play_y;
    padr_y <= ai_y;

    debounce_unit_fire : entity work.debounce(Behavioral)
        Port Map (clk => pixel_clk, input => btn_fire, 
        output => open, ondn => open, onup => sig_fire); 

    debounce_unit_up : entity work.debounce(Behavioral)
        Port Map (clk => pixel_clk, input => btn_up, 
        output => sig_up, ondn => open, onup => open);   

    debounce_unit_dn : entity work.debounce(Behavioral)
        Port Map (clk => pixel_clk, input => btn_dn, 
        output => sig_dn, ondn => open, onup => open);


    STATE_TRANSITION : process(state, state_next)
    begin
        case state is
            when NEW_GAME =>
                state_next <= POSITION;
            when POSITION =>
                state_next <= READY;
            when READY =>
                if sig_fire = '1' then
                    state_next <= PLAY;
                else
                    state_next <= READY;
                end if;
            when POINT =>
                if sig_fire = '1' then
                    state_next <= POSITION;
                else
                    state_next <= POINT;
                end if;
            when END_GAME =>
                if sig_fire = '1' then
                    state_next <= NEW_GAME;
                else
                    state_next <= END_GAME;
                end if;
            when PLAY =>
                if (coll_l = '1' or coll_r = '1') then
                    if (to_integer(unsigned(score_l)) = WIN or to_integer(unsigned(score_r)) = WIN) then
                        state_next <= END_GAME;
                    else
                        state_next <= POINT;
                    end if;
                else
                    state_next <= PLAY;
                end if;
            when others =>
                state_next <= NEW_GAME;
        end case;
    end process;
    
    -- update game state
    process(pixel_clk, state, state_next)
    begin
        if rising_edge(pixel_clk) then
            state <= state_next;
        end if;
    end process;

    -- AI paddle control
    AI_CONTROL: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if (state = POSITION) then
                ai_y <= to_unsigned(((V_RES - PAD_HEIGHT) / 2), ai_y'length);
            elsif (frame = '1' and state = PLAY) then
                if (ai_y + PAD_HEIGHT/2 < ball_y) then
                    if (ai_y + PAD_HEIGHT + PAD_SPY >= V_RES-1) then
                        ai_y <= to_unsigned(V_RES - PAD_HEIGHT - 1, ai_y'length);
                    else
                        ai_y <= ai_y + PAD_SPY;
                    end if;
                elsif (ai_y + PAD_HEIGHT/2 > ball_y + BALL_SIZE) then
                    if (ai_y < PAD_SPY) then
                        ai_y <= to_unsigned(0, ai_y'length);
                    else
                        ai_y <= ai_y - PAD_SPY;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- player paddle control
    PLAYER_CONTROL: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if (state = POSITION) then
                play_y <= to_unsigned(((V_RES - PAD_HEIGHT) / 2), play_y'length);
            elsif (frame = '1' and state = PLAY) then
                if (sig_dn = '1') then
                    if (play_y + PAD_HEIGHT + PAD_SPY >= V_RES-1) then
                        play_y <= to_unsigned(V_RES - PAD_HEIGHT - 1, play_y'length);
                    else
                        play_y <= play_y + PAD_SPY;
                    end if;
                elsif (sig_up = '1') then
                    if (play_y < PAD_SPY) then
                        play_y <= to_unsigned(0, play_y'length);
                    else
                        play_y <= play_y - PAD_SPY;
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- ball control
    BALL_CONTROL: process(pixel_clk)
    begin
    if rising_edge(pixel_clk) then
        case state is
        when NEW_GAME =>
            score_l <= (others => '0');
            score_r <= (others => '0');

        when POSITION =>
            coll_l <= '0';
            coll_r <= '0';
            ball_spx <= to_unsigned(BALL_ISPX, ball_spx'length);
            ball_spy <= to_unsigned(BALL_ISPY, ball_spy'length);
            shot_cnt <= (others => '0');

            ball_y <= to_unsigned(((V_RES - BALL_SIZE) / 2), ball_y'length);
            if (coll_r = '1') then
                ball_x <= to_unsigned(H_RES - (PAD_OFFS + PAD_WIDTH + BALL_SIZE), ball_x'length);
                ball_dx <= '1';
            else
                ball_x <= to_unsigned(PAD_OFFS + PAD_WIDTH, ball_x'length);
                ball_dx <= '0';
            end if;

        when PLAY =>
            if (frame = '1') then
                -- horizontal ball position
                if (ball_dx = '0') then
                    if (ball_x + BALL_SIZE + ball_spx >= H_RES-1) then
                        ball_x <= to_unsigned(H_RES - BALL_SIZE, ball_x'length);
                        score_l <= score_l + 1;
                        coll_r <= '1';
                    else
                        ball_x <= ball_x + ball_spx;
                    end if;
                else 
                    if (ball_x < ball_spx) then
                        ball_x <= to_unsigned(0, ball_x'length);
                        score_r <= score_r + 1;
                        coll_l <= '1';
                    else
                        ball_x <= ball_x - ball_spx;
                    end if;
                end if;

                -- vertical ball position
                if (ball_dy = '0') then
                    if (ball_y + BALL_SIZE + ball_spy >= V_RES-1) then
                        ball_dy <= '1';
                    else
                        ball_y <= ball_y + ball_spy;
                    end if;
                else 
                    if (ball_y < ball_spy) then
                        ball_dy <= '0';
                    else
                        ball_y <= ball_y - ball_spy;
                    end if;
                end if;

                -- ball speed increases after SPEEDUP shots
                if (ball_dx_prev /= ball_dx) then
                    shot_cnt <= shot_cnt + 1;
                end if;
                if (shot_cnt = SPEEDUP) then
                    if (ball_spx < PAD_WIDTH) then
                        ball_spx <= ball_spx + 1;
                    else
                        ball_spx <= ball_spx;
                    end if;
                    ball_spy <= ball_spy + 1;
                    shot_cnt <= (others => '0');
                end if;

            end if;
        when others =>
            null;
        end case;

        -- change direction if ball collides with paddle
        if (ball = '1' and padl = '1' and ball_dx = '1') then
            ball_dx <= '0';
        end if;
        if (ball = '1' and padr = '1' and ball_dx = '0') then
            ball_dx <= '1';
        end if;

        if (frame = '1') then
            ball_dx_prev <= ball_dx;
        end if;
    end if;
    end process;

    ball <= '1' when (hcount >= ball_x) and (hcount < ball_x + BALL_SIZE) and (vcount >= ball_y) and (vcount < ball_y + BALL_SIZE)  else '0';
    padl <= '1' when (hcount >= PAD_OFFS) and (hcount < PAD_OFFS + PAD_WIDTH) and (vcount >= padl_y) and (vcount < padl_y + PAD_HEIGHT) else '0';
    padr <= '1' when (hcount >= H_RES - PAD_OFFS - PAD_WIDTH - 1) and (hcount < H_RES - PAD_OFFS - 1) and (vcount >= padr_y) and (vcount < padr_y + PAD_HEIGHT) else '0';

    -- instantiate simple_score
    simple_score_unit : entity work.simple_score(Behavioral)
        Port Map (clk_pix => pixel_clk, sx => hcount, sy => vcount, score_l => score_l, score_r => score_r, pix => pix_score);


    process(pix_score, paint_red, paint_green, paint_blue)
    begin
        if (pix_score = '1') then
            paint_red <= "1111";
            paint_green <= "0011";
            paint_blue <= "0000";
        elsif (ball = '1') then
            paint_red <= "1111";
            paint_green <= "1100";
            paint_blue <= "0000";
        elsif (padl = '1' or padr = '1') then
            paint_red <= "1111";
            paint_green <= "1111";
            paint_blue <= "1111";
        else
            paint_red <= "0001";
            paint_green <= "0011";
            paint_blue <= "0111";
        end if;
    end process;

    vgaRed <= paint_red when blanking = '0' else (others => '0');
    vgaGreen <= paint_green when blanking = '0' else (others => '0');
    vgaBlue <= paint_blue when blanking = '0' else (others => '0');


end Behavioral;