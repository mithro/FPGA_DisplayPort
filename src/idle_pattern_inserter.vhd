library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity idle_pattern_inserter is
        port ( 
            clk              : in  std_logic;
            channel_ready    : in  std_logic;
            source_ready     : in  std_logic;
            in_data0         : in  std_logic_vector(7 downto 0);
            in_data0k        : in  std_logic;
            in_data1         : in  std_logic_vector(7 downto 0);
            in_data1k        : in  std_logic;
            in_switch_point  : in  std_logic;

            out_data0        : out std_logic_vector(7 downto 0);
            out_data0k       : out std_logic;
            out_data1        : out std_logic_vector(7 downto 0);
            out_data1k       : out std_logic
        );
end entity; 

architecture arch of idle_pattern_inserter is
    signal count_to_switch   : unsigned(16 downto 0) := (others => '0');
    signal source_ready_last : std_logic := '0';
    signal idle_switch_point : std_logic := '0';
    
    signal idle_count : unsigned(12 downto 0) := (others => '0');    

    constant BS     : std_logic_vector(8 downto 0) := "110111100";   -- K28.5
    constant DUMMY  : std_logic_vector(8 downto 0) := "000000011";   -- 0x3
    constant VB_ID  : std_logic_vector(8 downto 0) := "000001001";   -- 0x09  VB-ID with no video asserted 
    constant Mvid   : std_logic_vector(8 downto 0) := "000000000";   -- 0x00
    constant Maud   : std_logic_vector(8 downto 0) := "000000000";   -- 0x00    

    signal idle_d0: std_logic_vector(8 downto 0);
    signal idle_d1: std_logic_vector(8 downto 0);
    
begin

process(clk) 
    begin
        if rising_edge(clk) then
            if count_to_switch(16) = '1' then
                out_data0  <= in_data0;
                out_data0k <= in_data0k;
                out_data1  <= in_data1;
                out_data1k <= in_data1k;
            else
                out_data0   <= idle_d0(7 downto 0);
                out_data0k  <= idle_d0(8);
                out_data1   <= idle_d1(7 downto 0);
                out_data1k  <= idle_d1(8);
                -- send idle pattern
            end if;
            if count_to_switch(16) = '0' then
                -- The last tick over requires the source to be ready
                -- and to be asserting that it is in the switch point.
                if count_to_switch(15 downto 0) = x"FFFF" then
                    if source_ready = '1' and in_switch_point = '1' and idle_switch_point = '1' then
                        count_to_switch <= count_to_switch + 1;
                    end if;
                else
                   -- Wait while we send out at least 64k of idle patterns
                   count_to_switch <= count_to_switch + 1;
                end if;
            end if;
            ------------------------------------------------------------------------
            -- If either the source drops or the channel is not ready, then reset
            -- to emitting the idle pattern. 
            ------------------------------------------------------------------------
            if channel_ready = '0' or (source_ready = '0' and source_ready_last = '1') then
                count_to_switch <= (others => '0');
            end if;
            source_ready_last  <= source_ready;
            
            -------------------------------------------------------------------------------            
            -- We can either be odd or even aligned, depending on where the last BS symbol
            -- was seen. We need to send the next one 8192 symbols later (4096 cycles)
            -------------------------------------------------------------------------------            
            idle_switch_point <= '0';
            if idle_count = 0 then
                idle_d0 <= DUMMY;
                idle_d1 <= DUMMY;
            elsif idle_count = 2 then
                idle_d0 <= BS;
                idle_d1 <= VB_ID;             
            elsif idle_count = 4 then
                idle_d0 <= Mvid;
                idle_d1 <= Maud;
            elsif idle_count = 6 then
                idle_d0 <= VB_ID;
                idle_d1 <= Mvid;
            elsif idle_count = 8 then
                idle_d0 <= Maud;
                idle_d1 <= VB_ID;
            elsif idle_count = 10 then
                idle_d0 <= Mvid;
                idle_d1 <= Maud;
            elsif idle_count = 12 then
                idle_d0 <= VB_ID;
                idle_d1 <= Mvid;
            elsif idle_count = 14 then
                idle_d0 <= Maud;
                idle_d1 <= DUMMY;
                
            elsif idle_count = 1 then
                idle_d0 <= DUMMY;
                idle_d1 <= BS;
            elsif idle_count = 3 then
                idle_d0 <= VB_ID;             
                idle_d1 <= Mvid;
            elsif idle_count = 5 then
                idle_d0 <= Maud;
                idle_d1 <= VB_ID;
            elsif idle_count = 7 then
                idle_d0 <= Mvid;
                idle_d1 <= Maud;
            elsif idle_count = 9 then
                idle_d0 <= VB_ID;
                idle_d1 <= Mvid;
            elsif idle_count = 11 then
                idle_d0 <= Maud;
                idle_d1 <= VB_ID;
            elsif idle_count = 12 then
                idle_d0 <= VB_ID;
                idle_d1 <= Mvid;
            elsif idle_count = 13 then
                idle_d0 <= Mvid;
                idle_d1 <= Maud;
            elsif idle_count = 15 then
                idle_d0 <= DUMMY;
                idle_d1 <= DUMMY;
            else
                idle_d0 <= DUMMY;
                idle_d1 <= DUMMY;         -- can switch to the actual video at any other time
                idle_switch_point <= '1'; -- other than when the BS, VB-ID, Mvid, Maud sequence
            end if; 

            idle_count <= idle_count + 2;            
            -------------------------------------------------------  
            -- Sync with thr BS stream of the input signal but only 
            -- if we are switched over to it (indicated by the high
            -- bit of count_to_switch being set)
            -------------------------------------------------------  
            if count_to_switch(16) = '1' then
                if (in_data0k & in_data0) = BS then
                    idle_count <= to_unsigned(2,idle_count'length);
                elsif (in_data1k & in_data1) = BS then
                    idle_count <= to_unsigned(1,idle_count'length);
                end if; 
            end if; 
        end if;
    end process;
end architecture;