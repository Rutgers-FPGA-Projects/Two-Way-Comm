LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;

ENTITY uart IS
	PORT (CLOCK_50,AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK,AUD_ADCDAT			:IN STD_LOGIC;
			CLOCK2_50														:IN STD_LOGIC;
			KEY																:IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			I2C_SDAT														:INOUT STD_LOGIC;
			I2C_SCLK,AUD_DACDAT,AUD_XCK										:OUT STD_LOGIC;
			UART_TXD														:OUT STD_LOGIC;
			UART_RXD														:IN STD_LOGIC);
END uart;

ARCHITECTURE Behavior OF uart IS
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
	COMPONENT TX
		PORT(
			CLK:IN STD_LOGIC;
			START:IN STD_LOGIC;
			BUSY:OUT STD_LOGIC;
			DATA: IN STD_LOGIC_VECTOR(23 downto 0);
			TX_LINE:OUT STD_LOGIC
		);
	END COMPONENT TX;
----------------------------------------
	COMPONENT RX
		PORT(
			CLK:IN STD_LOGIC;
			RX_LINE:IN STD_LOGIC;
			DATA:OUT STD_LOGIC_VECTOR(23 downto 0);
			BUSY:OUT STD_LOGIC
		);
	END COMPONENT RX;

	SIGNAL read_ready, write_ready, read_s, write_s				:STD_LOGIC;
	SIGNAL readdata_left, readdata_right 							:STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL writedata_left, writedata_right							:STD_LOGIC_VECTOR(23 DOWNTO 0);	
	--SIGNAL DATA, RECEIVE																:STD_LOGIC_VECTOR(23 DOWNTO 0);--:="000000000000000000000000";	
	SIGNAL reset, out_en													:STD_LOGIC;
	
	SIGNAL TX_DATA: STD_LOGIC_VECTOR(23  downto 0);
	SIGNAL TX_START: STD_LOGIC:='0';
	SIGNAL TX_BUSY: STD_LOGIC;
	SIGNAL RX_DATA: STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL RX_BUSY: STD_LOGIC;
BEGIN	
	C1: TX PORT MAP (CLOCK_50,TX_START,TX_BUSY,TX_DATA,UART_TXD);
	C2: RX PORT MAP (CLOCK_50,UART_RXD,RX_DATA,RX_BUSY);
	PROCESS(RX_BUSY, WRITE_READY)
	BEGIN
		IF(RX_BUSY='0' AND WRITE_READY='1')THEN--RX_BUSY'EVENT AND 
			WRITE_S <= '1';           --writes to buffer in audio codec
			writedata_left<=RX_DATA;  --writes out to speaker, the 24bit audio data.
		ELSIF(WRITE_READY='0')THEN
			WRITE_S<='0';
		END IF;
	END PROCESS;
	PROCESS(CLOCK_50, READ_READY)
	BEGIN
		IF(CLOCK_50'EVENT AND CLOCK_50='1')THEN
			IF(KEY(0)='0' AND TX_BUSY='0' AND READ_READY='1')THEN
				READ_S=<='1';
				TX_DATA<=readdata_left; --transmits read data from mic.  Serializes the 24bit data.
				TX_START<='1';
			ELSE
				TX_START<='0';
				READ_S<='0';
			END IF;
		END IF;
	END PROCESS;
	
	my_clock_gen: clock_generator PORT MAP (CLOCK2_50, reset, AUD_XCK);
	cfg: audio_and_video_config PORT MAP (CLOCK_50, reset, I2C_SDAT, I2C_SCLK);
	codec: audio_codec PORT MAP(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);
	--UA: UART PORT MAP(CLOCK_50,KEY(2),UART_TXD,UART_RXD,DATA,RECEIVE);
END Behavior;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
--------------------------------------------------------------------------------------------- 
 
ENTITY TX IS
	PORT(
		CLK:IN STD_LOGIC;
		START:IN STD_LOGIC;
		BUSY:OUT STD_LOGIC;
		DATA: IN STD_LOGIC_VECTOR(23 downto 0);
		TX_LINE:OUT STD_LOGIC
	);
END TX;
 
ARCHITECTURE MAIN OF TX IS
 
	SIGNAL PRSCL: INTEGER RANGE 0 TO 434:=0;
	SIGNAL INDEX: INTEGER RANGE 0 TO 29:=0;
	SIGNAL DATAFLL: STD_LOGIC_VECTOR(29 DOWNTO 0);
	SIGNAL TX_FLG: STD_LOGIC:='0';

BEGIN
	PROCESS(CLK)
	BEGIN
		IF(CLK'EVENT AND CLK='1')THEN
			IF(TX_FLG='0' AND START='1')THEN
				TX_FLG<='1';
				BUSY<='1';
				DATAFLL(0)<='0';
				DATAFLL(9)<='1';
				DATAFLL(10)<='0';
				DATAFLL(19)<='1';
				DATAFLL(20)<='0';
				DATAFLL(29)<='1';
				DATAFLL(8 DOWNTO 1)<=DATA(7 DOWNTO 0);      --creates single vector for 24 bit audio data with start and stop bits for a total of 30 bits.
				DATAFLL(18 DOWNTO 11)<=DATA(15 DOWNTO 8);
				DATAFLL(28 DOWNTO 21)<=DATA(23 DOWNTO 16);
			END IF;
 
			IF(TX_FLG='1')THEN
				IF(PRSCL<433)THEN         --precales for 50000/115200 = 434
					PRSCL<=PRSCL+1;
				ELSE	
					PRSCL<=0;
				END IF;
 
				IF(PRSCL=217)THEN         --takes the median for timing.
					TX_LINE<=DATAFLL(INDEX);
					IF(INDEX<29)THEN
						INDEX<=INDEX+1;
					ELSE
						TX_FLG<='0';
						BUSY<='0';
						INDEX<=0;
					END IF;
				END IF;	
			END IF;
		END IF;
	END PROCESS;
END MAIN;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
 ----------------------------------------------------------------------------------------------
 
ENTITY RX IS
	PORT(
		CLK:IN STD_LOGIC;
		RX_LINE:IN STD_LOGIC;
		DATA:OUT STD_LOGIC_VECTOR(23 downto 0);
		BUSY:OUT STD_LOGIC
	);
END RX;
 
ARCHITECTURE MAIN OF RX IS
	SIGNAL DATAFLL: STD_LOGIC_VECTOR(29 downto 0);
	SIGNAL RX_FLG: STD_LOGIC:='0';
	SIGNAL PRSCL: INTEGER RANGE 0 TO 434:=0;
	SIGNAL INDEX: INTEGER RANGE 0  TO 29:=0;
BEGIN
	PROCESS(CLK)
	BEGIN
		IF(CLK'EVENT AND CLK='1')THEN
			IF(RX_FLG='0' AND RX_LINE='0')THEN
				INDEX<=0;
				PRSCL<=0;
				BUSY<='1';
				RX_FLG<='1';
			END IF;
 
			IF(RX_FLG='1')THEN
				DATAFLL(INDEX)<=RX_LINE;
				IF(PRSCL<433)THEN           --same prescale as TxD
					PRSCL<=PRSCL+1;
				ELSE
					PRSCL<=0;
				END IF;
				IF(PRSCL=217)THEN           -same median as TxD
					IF(INDEX<29)THEN
						INDEX<=INDEX+1;
					ELSE
						IF(DATAFLL(0)='0' AND DATAFLL(9)='1' AND DATAFLL(10)='0' AND DATAFLL(19)='1' AND DATAFLL(20)='0' AND DATAFLL(29)='1')THEN
							DATA(7 DOWNTO 0) <=DATAFLL(8 DOWNTO 1);
							DATA(15 DOWNTO 8) <=DATAFLL(18 DOWNTO 11);              -- Serializes 24bit data to transmit 1 bit at a time.
							DATA(23 DOWNTO 16) <=DATAFLL(28 DOWNTO 21);
						ELSE
							DATA<=(OTHERS=>'0');
						END IF;
						RX_FLG<='0';
						BUSY<='0';
					END IF;
				END IF;  
			END IF;
		END IF;
	END PROCESS;
END MAIN;
