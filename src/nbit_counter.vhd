----------------------------------------------------------------------------------
-- Author: Akshay Gopinath 
-- Module Name: nbit_counter - Behavioral
-- Dependancies: None
-- Project Name: CE339 Assignment 1
-- Target Devices: Digilent Basys 3 
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

entity nbit_counter is
    Generic (width  : NATURAL := 4;
             modulo : NATURAL := 16);
    Port ( clk    : in  STD_LOGIC;
           cin    : in  STD_LOGIC;
           negate : in  STD_LOGIC;
           rst    : in  STD_LOGIC;
           cout   : out STD_LOGIC;
           output : out STD_LOGIC_VECTOR ((width-1) downto 0));
end nbit_counter;

architecture Behavioral of nbit_counter is
    Signal count : UNSIGNED (output'RANGE) := (others => '0');
begin
    process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count <= (others => '0');
            elsif (cin = '1') and (count = (modulo-1)) then
                count <= (others => '0');
            elsif (cin = '1') then
                count <= count + 1;
            end if;
        end if;
    end process;

    cout <= '1' when (cin = '1') and (count = (modulo-1)) else '0';
    output <= STD_LOGIC_VECTOR(count) when negate = '0' else STD_LOGIC_VECTOR(not count);

end Behavioral;
