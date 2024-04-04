----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/29/2024 03:53:39 PM
-- Design Name: 
-- Module Name: simple_score - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity simple_score is
    Port ( clk_pix : in STD_LOGIC;
           sx : in unsigned (10 downto 0);
           sy : in unsigned (10 downto 0);
           score_l : in unsigned (3 downto 0);
           score_r : in unsigned (3 downto 0);
           pix : out STD_LOGIC);
end simple_score;

architecture Behavioral of simple_score is
    constant H_RES : integer := 640;
    constant CORDW : integer := 11;

    type BitmapArray is array (0 to 9) of STD_LOGIC_VECTOR(0 to 14);

    signal chars : BitmapArray := (
        "111101101101111",
        "110010010010111",
        "111001111100111",
        "111001011001111",
        "101101111001001",
        "111100111001111",
        "100100111101111",
        "111001001001001",
        "111101111101111",
        "111101111001001"
    );

    signal char_l, char_r : unsigned(3 downto 0);
    signal score_l_region, score_r_region : std_logic;

    Signal pix_addr : unsigned (3 downto 0);
begin

    char_l <= score_l when score_l < 10 else (others => '0');
    char_r <= score_r when score_r < 10 else (others => '0');

    score_l_region <= '1' when (sx >= 7 and sx < 19 and sy >= 8 and sy < 28) else '0';
    score_r_region <= '1' when (sx >= H_RES-22 and sx < H_RES-10 and sy >= 8 and sy < 28) else '0';

    process(score_l_region, score_r_region, pix_addr)
    begin
        if score_l_region = '1' then
            pix_addr <= to_unsigned(((to_integer(sx)-7)/4 + 3*((to_integer(sy)-8))/4), pix_addr'length);
        elsif score_r_region = '1' then
            pix_addr <= to_unsigned(((to_integer(sx)-(H_RES-22))/4 + 3*((to_integer(sy)-8))/4), pix_addr'length);
        else
            pix_addr <= (others => '0');
        end if;
    end process;

    process(clk_pix)
    begin
        if rising_edge(clk_pix) then
            if score_l_region = '1' then
                pix <= chars(to_integer(char_l))(to_integer(pix_addr));
            elsif score_r_region = '1' then
                pix <= chars(to_integer(char_r))(to_integer(pix_addr));
            else
                pix <= '0';
            end if;
        end if;
    end process;


end Behavioral;
