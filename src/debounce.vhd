library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity debounce is
    Port ( clk : in STD_LOGIC;
           input : in STD_LOGIC;
           output : inout STD_LOGIC;
           ondn : out STD_LOGIC;
           onup : out STD_LOGIC);
end debounce;

architecture Behavioral of debounce is
    Signal sync_0 : STD_LOGIC;
    Signal sync_1 : STD_LOGIC;
    Signal count : unsigned(17 downto 0);
    Signal idle, max : STD_LOGIC;
begin

process(clk)
begin
    if rising_edge(clk) then
        sync_0 <= input;
        sync_1 <= sync_0;
    end if;
end process;

idle <= '1' when (output = sync_1) else '0';
max <= '1' when count = "111111111111111111" else '0';
ondn <= (not idle) and max and (not output);
onup <= (not idle) and max and output;

process(clk)
begin
    if rising_edge(clk) then
        if idle = '1' then
            count <= (others => '0');
        else
            count <= count + 1;
            if max = '1' then
                output <= not output;
            end if;
        end if;
    end if;
end process;


end Behavioral;
