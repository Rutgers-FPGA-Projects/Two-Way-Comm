LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;

ENTITY part1 IS
	PORT (CLOCK_50,AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK,AUD_ADCDAT			:IN STD_LOGIC;
			CLOCK2_50																		:IN STD_LOGIC;
			KEY																				:IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			GPIO																				:INOUT STD_LOGIC_VECTOR(25 DOWNTO 0);
			LEDR																				:OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
			LEDG																				:OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			I2C_SDAT																			:INOUT STD_LOGIC;
			I2C_SCLK,AUD_DACDAT,AUD_XCK												:OUT STD_LOGIC;
			SW																					:IN STD_LOGIC_VECTOR(0 DOWNTO 0));
END part1;

ARCHITECTURE Behavior OF part1 IS
	COMPONENT clock_generator
		PORT(	CLOCK2_50														:IN STD_LOGIC;
		    	reset															:IN STD_LOGIC;
				AUD_XCK														:OUT STD_LOGIC);
	END COMPONENT;

	COMPONENT audio_and_video_config
		PORT(	CLOCK_50,reset												:IN STD_LOGIC;
		    	I2C_SDAT														:INOUT STD_LOGIC;
				I2C_SCLK														:OUT STD_LOGIC);
	END COMPONENT;	

	COMPONENT audio_codec
		PORT(	CLOCK_50,reset,read_s,write_s							:IN STD_LOGIC;
				writedata_left, writedata_right						:IN STD_LOGIC_VECTOR(23 DOWNTO 0);
				AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK		:IN STD_LOGIC;
				read_ready, write_ready									:OUT STD_LOGIC;
				readdata_left, readdata_right							:OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
				AUD_DACDAT													:OUT STD_LOGIC);
	END COMPONENT;

	SIGNAL read_ready, write_ready, read_s, write_s				:STD_LOGIC;
	SIGNAL readdata_left, readdata_right 							:STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL writedata_left, writedata_right							:STD_LOGIC_VECTOR(23 DOWNTO 0);	
	SIGNAL DATA																:STD_LOGIC_VECTOR(23 DOWNTO 0):="000000000000000000000000";	
	SIGNAL reset, out_en													:STD_LOGIC;


BEGIN
reset <= NOT(KEY(0));
out_en <= NOT(KEY(1));
--PROCESS(out_en)
--BEGIN
--	IF out_en = '1' THEN 
--		GPIO(23 DOWNTO 0) <= tempx0;
--	ELSE 
--		GPIO(23 DOWNTO 0) <= (OTHERS => 'Z');
--	END IF;
--END PROCESS;
GPIO(23 DOWNTO 0) <=  DATA when ( out_en = '1') else ( others=>'Z' );
	

PROCESS (read_ready,KEY(1))
	BEGIN
		IF(read_ready = '1' AND NOT(KEY(1)) = '1') THEN
			read_s <= '1';
			DATA <= readdata_left;
		ELSIF (read_ready = '0' AND NOT(KEY(1)) = '1') THEN
			read_s <= '0';
		END IF;
	END PROCESS;

PROCESS (write_ready,KEY(1))
BEGIN
	IF(write_ready = '1' AND NOT(KEY(1)) = '0') THEN
		write_s <= '1';
		writedata_left <= GPIO(23 DOWNTO 0);
		writedata_right <= GPIO(23 DOWNTO 0);
	ELSIF (write_ready = '0' AND NOT(KEY(1)) = '0') THEN
		write_s <= '0';
	END IF;
END PROCESS;
--	PROCESS(SW(0),read_ready,write_ready)
--	BEGIN
--		IF(SW(0) = '1') THEN
--			IF(read_ready = '1') THEN
--				GPIO(23 DOWNTO 0) <= readdata_left;
--				read_s <= '1';
--			ELSE
--				read_s <= '0';
--			END IF;
--		ELSIF(SW(0) = '0') THEN
--			IF(write_ready = '1') THEN
--				writedata_left <= GPIO(23 DOWNTO 0);
--				writedata_right <= GPIO(23 DOWNTO 0);
--				write_s <= '1';
--			ELSE
--				write_s <= '0';
--			END IF;
--		END IF;
--	END PROCESS;
	
	my_clock_gen: clock_generator PORT MAP (CLOCK2_50, reset, AUD_XCK);
	cfg: audio_and_video_config PORT MAP (CLOCK_50, reset, I2C_SDAT, I2C_SCLK);
	codec: audio_codec PORT MAP(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);

END Behavior;
