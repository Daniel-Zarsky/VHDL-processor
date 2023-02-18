-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;



-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

-- Program counter 
    signal pc_inc : std_logic;
    signal pc_dec : std_logic;
    signal pc_mx : std_logic_vector(12 downto 0); --8192 adresses
 --   signal mx_pc_input : std_logic_vector(12 downto 0); -- signal between pc and mx 
-- Program counter 

--Counter 
     signal cnt_inc : std_logic;
     signal cnt_dec : std_logic;
     signal cnt_out : std_logic_vector(7 downto 0); -- 8bit instrukce ??
--Counter 

--Pointer
  signal ptr_inc : std_logic;
  signal ptr_dec : std_logic;
   signal ptr_mx : std_logic_vector(12 downto 0); --8192 adresses 
  -- signal mx_ptr_input : std_logic_vector(12 downto 0); -- signal between pointer and mx 
--Pointer

--STATES 
    type fsm_state is (
      start,
      s_fetch,
      s_decode,
      s_ptr_inc,
      s_ptr_dec,
      s_value_inc_1,
      s_value_inc_2,
      s_value_inc_3,
      s_value_inc_4,
      s_value_dec_1, 
      s_value_dec_2, 
      s_value_dec_3, 
      s_value_dec_4,
      s_write_1,
      s_write_2, 
      s_load_1, 
       s_load_2,
      s_halt,
      s_while_start,
      s_while_skip_1,
      s_while_skip_2,
      s_while_skip_3,
      s_while_end,
      -- s_while_end_2,
      s_loop_inverse_1,
      s_loop_inverse_2,
     s_dowhile_start,
     s_dowhile_end 
    
    );
    signal state : fsm_state := start;
    signal next_state : fsm_state := start;
--STATES 

--mux1 
 signal mux1_out :std_logic_vector(12 downto 0) := (others => '0'); --selected output 
  signal mux1_sel :std_logic_vector(1 downto 0) := (others => '0'); --selcting between program and pointer 
--mux1 

--mux2
  signal mux2_out :std_logic_vector(7 downto 0) := (others => '0'); --DATA WDATA
  signal mux2_sel :std_logic_vector(1 downto 0) := (others => '0'); --selection of oprations 
--mux2 

---BEGIN CPU BEHAVIORAL ARCHITECTURE 
begin 

--PROGRAM COUNTER 
          prg_cnt: process(CLK, RESET, pc_inc, pc_dec) is 
          begin 
              if RESET = '1'then 
              pc_mx <= (others => '0');

              elsif (CLK'event) and CLK = '1' then 

                if pc_inc = '1' then
                    pc_mx <= pc_mx + 1;

                elsif pc_dec = '1' then 
                  pc_mx <= pc_mx - 1;

                end if;

              end if;

          end process;
--PROGRAM COUNTER 

--POINTER 
        pointer: process(CLK, RESET, ptr_inc, ptr_dec) is 
        begin 
            if RESET = '1'then 
            ptr_mx <= "1000000000000"; --ptr_mx - signal mezi PTR a MUX1
            
            elsif (CLK'event) and CLK = '1' then 
            
               if ptr_inc = '1' and ptr_mx = "1111111111111" then
                    ptr_mx <= "1000000000000";

                elsif ptr_inc = '1' then 
                  ptr_mx <= ptr_mx + 1;

                elsif ptr_dec = '1' and ptr_mx = "1000000000000" then 
                  ptr_mx <= "1111111111111";

                elsif ptr_dec = '1' then 
                  ptr_mx <= ptr_mx - 1;


                end if;

                
            end if;

        end process;  
--POINTER

--COUNTER 
 cnt_cntr: process (CLK, RESET, cnt_inc, cnt_dec)
	begin
		if RESET = '1' then
			cnt_out <= (others => '0');
		elsif (CLK'event) and CLK = '1' then 
			if cnt_inc = '1' then
				cnt_out <= cnt_out + 1;
			elsif cnt_dec = '1' then
				cnt_out <=  cnt_out - 1;
      end if;
    end if;
 end process;
--COUNTER 

--MUX1 
  mx_1 : process ( RESET, mux1_sel, pc_mx, ptr_mx)
    begin
      if RESET = '1' then
        mux1_out <= (others => '0');
      else
        case mux1_sel is

          when "01" => -- hodnota z program counteru jde do mux 1 
              mux1_out <= pc_mx;
          when "10" => -- hodnota z pointeru (do pameti) jde do mux 1 
              mux1_out <= ptr_mx;

          when others =>
            mux1_out <= (others => '0');

        end case;
      end if;
    end process;

	DATA_ADDR <= mux1_out;
 --MUX1 

 --MUX2 -- ready 
  mx_2 : process ( RESET, IN_DATA, mux2_sel)
    begin
      if RESET = '1' then
        mux2_out <= (others => '0');
      else
        case mux2_sel is
            when "11" =>
            -- Nacti data do bunky 
            mux2_out <= IN_DATA;

          when "01" =>
            -- Inkrement bunky
            
            mux2_out <= DATA_RDATA + 1;

          when "10" =>
            -- Dekrement bunky
            
            mux2_out <= DATA_RDATA - 1;

          when others =>
            mux2_out<= (others => '0');

        end case;
      end if;
    end process;

	DATA_WDATA <= mux2_out;
--MUX2 

--FSM - LOADING STATE 
pstatereg: process(EN, RESET, CLK)
begin
  if (RESET='1') then
        state <= start;
  elsif (CLK'event) and (CLK='1') and (EN =  '1') then
       state <= next_state;
  end if;
end process;
--FSM - LOADING STATE 


--FSM
next_state_logic: process(state, IN_VLD, OUT_BUSY, DATA_RDATA, cnt_out)
begin 
   --init values 
    
    pc_inc <= '0';
    pc_dec <= '0';
    ptr_inc <= '0';
    ptr_dec <= '0';
    
    cnt_inc <= '0';
    cnt_dec <='0';

    mux1_sel <= "00";
    mux2_sel <= "00";

    OUT_DATA <= "00000000";

    DATA_RDWR <= '0';
    DATA_EN <= '0';
    IN_REQ <= '0';
    OUT_WE <= '0';
   --init values 

   case state is 
      when start => 
        next_state <= s_fetch;

      when s_fetch =>
    
        --NACTENI KODU - nacteno bude v dalsim clocku 
         DATA_EN <= '1';     --povoluji praci s ram           
         mux1_sel <= "01"; -- mux1 zvoli adresu v prg counteru 

         next_state <= s_decode;

      when s_decode=>
           
         case DATA_RDATA is 
               
              when X"3E" => 
              next_state <= s_ptr_inc;

              when X"3C" =>
              next_state <= s_ptr_dec;

              when X"2B" =>
              next_state <= s_value_inc_1;

              when X"2D" =>
              next_state <= s_value_dec_1;

              when  X"28" =>
              next_state <= s_dowhile_start;

               when X"29" => 
                 next_state <= s_dowhile_end;

             when  X"5B" => 
               next_state <= s_while_start;

              when  X"5D" => 
               next_state <= s_while_end;

              when X"2E" => 
              next_state <= s_write_1;

              when X"2C" => 
              next_state <= s_load_1;

              when X"00" => 
              next_state <= s_halt;

              when others => 
              pc_inc <= '1';
              next_state <= s_fetch;
              
         end case;   ---konec dekodovani 
         

           ---POINTER INCREMENT  > 
         when s_ptr_inc =>

              ptr_inc <= '1';
              pc_inc <= '1';
              mux1_sel <= "10"; 
  
              next_state <= s_fetch;

           ---POINTER DECREMENT < 
         when s_ptr_dec =>

                pc_inc <= '1';
                ptr_dec <= '1';
                mux1_sel <= "10";
                 next_state <= s_fetch;

          
          ---INCREMENT 
          when s_value_inc_1 =>

              --CTENI R_DATA 
             DATA_EN <= '1';        --povoluji praci s daty
              mux1_sel <= "10";      --pristupuju do pameti (01 = program, 10 = pamet) -az u prictiho clk
              
              next_state <= s_value_inc_2; --TODO PREDELAT
           
           when s_value_inc_2 =>
            
             -- R_data je nacteny a presune se na wdata 
               DATA_EN <= '1';
                      
 
           next_state <= s_value_inc_3;

           when s_value_inc_3 =>
              -- w_data se zapisou 
             mux2_sel <= "01";        --increment R_DATA (11 IN Data, 10 decrement, 01 increment)
             mux1_sel <= "10";        --pristup do pameti/pointeru 
             DATA_RDWR <= '1';        ---chci prepsat data 
             DATA_EN <= '1';         ---povoluji praci s daty
         
           next_state <= s_value_inc_4;

           when s_value_inc_4 => 
              -- ukonceni prace s pameti 
               DATA_EN <= '0';  -- konec prace s daty 
               DATA_RDWR <= '0'; -- pouze cteni 
              
               pc_inc <= '1'; -- dalsi insrukce 

           next_state <= s_fetch;


            ---DECREMENT VALUE 
          when s_value_dec_1 => 

               --CTENI R_DATA 
              DATA_EN <= '1';        --povoluji praci s daty
              mux1_sel <= "10";      --pristupuju do pameti (01 = program, 10 = pamet) -az u prictiho clk
             
              next_state <= s_value_dec_2;
 
          when s_value_dec_2 =>
               -- R_data je nacteny a presune se na wdata 
               DATA_EN <= '1';
             
               next_state <= s_value_dec_3;

          when s_value_dec_3 =>
                -- w_data se zapisou 
              mux2_sel <= "10";        --increment R_DATA (11 IN Data, 10 decrement, 01 increment)
              mux1_sel <= "10";        --pristup do pameti/pointeru 
              DATA_RDWR <= '1';        ---chci prepsat data 
              DATA_EN <= '1';         ---povoluji praci s daty
         

             next_state <= s_value_dec_4;

           when s_value_dec_4 =>
              -- ukonceni prace s pameti 
              DATA_EN <= '0';  -- konec prace s daty 
              DATA_RDWR <= '0'; -- pouze cteni 
              
              pc_inc <= '1'; -- dalsi insrukce 

            next_state <= s_fetch;

          ---LOAD
         when s_load_1 => 

            IN_REQ <= '1'; -- pozadavak na data 
         
             mux2_sel <= "11";  -- data wdata = in data 

          next_state <= s_load_2;

         when s_load_2 =>

          if IN_VLD /= '1' then
                  
                 
                  mux2_sel <= "11";  -- data wdata = in data 
                  IN_REQ <= '1'; -- stale zadam data 
                  next_state <= s_load_1;

            else 
                -- konec prace s daty 
                mux2_sel <= "11";
                mux1_sel <= "10"; --zapis na mem[ptr] a chod do pice 
                DATA_EN <= '1';
                DATA_RDWR <= '1';
                IN_REQ <= '0'; -- konec pozadavku na data 

                pc_inc <= '1'; -- dalsi instrukce 

                next_state <= s_fetch;
            end if; 

          when s_write_1 => 
          
              DATA_EN <= '1';
				      DATA_RDWR <= '0';
              mux1_sel <= "10"; --chci hodnotu z mem[ptr] 

              next_state <= s_write_2;


          when s_write_2 => 

            if OUT_BUSY /= '0' then
               next_state <= s_write_1;

            else
            
              OUT_DATA <= DATA_RDATA; --  vypisuj 
              OUT_WE <='1'; --povol vypis 

              pc_inc <= '1';
              next_state <= s_fetch;

            end if; 

       
          --WHILE 
          when s_while_start => 

          mux1_sel <= "10";  
          DATA_EN <= '1';
          if(mux1_sel = "10")  then 
            if (DATA_RDATA = "00000000") then 

                next_state <= s_while_skip_1;
                cnt_inc <= '1'; --??
                pc_inc <= '1';
               
              else 
                pc_inc <= '1';
                next_state <= s_fetch;
              
            end if;
          end if;

          when s_while_skip_1 =>
             
             DATA_EN <='1';
             mux1_sel <= "01"; --ctu instrukce  

            pc_inc <= '0';
            cnt_dec <= '0'; 

            cnt_inc <= '0';
             next_state <= s_while_skip_2;
          
          when s_while_skip_2 => 

            DATA_EN <='1';
           if(DATA_RDATA = X"5D") then
            cnt_dec <= '1';
           elsif (DATA_RDATA = X"5B") then
           cnt_inc <= '1';
           end if; 
          
            next_state <= s_while_skip_3;

          when s_while_skip_3 =>

           if(cnt_out = 0) then 
              pc_inc <= '1';
              next_state <= s_fetch;
            else 
              pc_inc <= '1';
              next_state <= s_while_skip_1;
            end if; 

          --DOWHILE 
          when s_dowhile_start => 

            cnt_dec <= '1'; 
            pc_inc <= '1';
            next_state <= s_fetch;

          when s_dowhile_end => 

          DATA_EN <= '1';
          mux1_sel <= "10"; --data
          cnt_inc <= '1';

          if(mux1_sel = "10") then 
            if(DATA_RDATA = "0000000")then 
             pc_inc <= '1';
                next_state <= s_fetch;
               
            else 
                 
                 pc_dec <= '1';
                next_state <= s_loop_inverse_1;

            end if; 

          end if;
          
          --WHILE+DOWHILE INVERSE 
          when s_loop_inverse_1 =>

           DATA_EN <= '1';
           mux1_sel <= "01";--instrukce 

           cnt_inc <= '0';
           cnt_dec <= '0';

           pc_dec <= '0';
          
           next_state <= s_loop_inverse_2;
 
          when s_loop_inverse_2 => 

           DATA_EN <= '1'; 
           
           if(DATA_RDATA = X"5D" or DATA_RDATA = X"29") then 
             cnt_inc <= '1';
           elsif (DATA_RDATA = X"5B" or DATA_RDATA = X"28") then 
             cnt_dec <= '1';
           end if;

           if(cnt_out = 0) then  --posledni zavorka 
              pc_dec <= '0'; 
              pc_inc <= '1';
              
              next_state <= s_fetch;
           else 
              pc_dec <= '1';
              
              next_state <= s_loop_inverse_1;
           end if; 


           when s_while_end => 
            
            DATA_EN <= '1';
           mux1_sel <= "10"; --data 
          

            DATA_EN <= '1';
           if (mux1_sel = "10") then
                if (DATA_RDATA = "00000000" ) then 
                  
                  next_state <= s_fetch;
                  pc_dec <= '0'; 
                  pc_inc <= '1';
                  else 
                     cnt_inc <= '1';
                    pc_dec <= '1';
                    next_state <= s_loop_inverse_1;

                end if; 
           end if;

          when s_halt => 
            next_state <= s_halt;
         
      
   end case;
end process;

--FSM

end behavioral; 


 
