; Christian Schroeder
; Hannah Sawiuk
; Jake Osborne
; ELEC 291, Project 1, Reflow Oven Controller
; Main file
$MODLP52

org 0x0000
   ljmp MainProgram
   
; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

;Macro that needs to be used by Macros.inc, as well as LCD_4Bit.inc, so it's included here to work for everything
;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
Wait_Milli_Seconds mac
	push AR2
	mov R2, %0
	lcall ?Wait_Milli_Seconds
	pop AR2
endmac

?Wait_Milli_Seconds:
	push AR0
	push AR1
L3: mov R1, #45
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*45=1.013ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret
;-------------------------------------------;
;               Constants                   ;
;-------------------------------------------;

MAX_TEMP_UPPER EQU 02	
MAX_TEMP_LOWER EQU 35 
CLK            EQU 22118400
BAUD		   EQU 115200
T1LOAD 		   EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RATE    EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD  EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE    EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD  EQU ((65536-(CLK/TIMER2_RATE)))   
 
;-------------------------------------------;
;                Variables                  ;
;-------------------------------------------;

DSEG at 30H

Temperature:	 ds 5 ;temperature BCD value
Count1ms: 		 ds 2 ; used to count for one second

Secs_BCD:		 ds 5 ;These two values are for the displayed runtime
Mins_BCD:		 ds 5

BCD_soak_temp: 	 ds 5 ;BCD value of Soak state temperature setting
BCD_soak_time: 	 ds 5 ;BCD values of set soak time in seconds
BCD_reflow_temp: ds 5
BCD_reflow_time: ds 5
SoakTime_Secs:   ds 5
SoakTime_Mins:   ds 5
ReflowTime_Secs: ds 5
ReflowTime_Mins: ds 5

;arithmetic variables
x: 			 	 ds 4
y: 		   		 ds 4
Result: 		 ds 2	

;-------------------------------------------;
;                  Flags                    ;
;-------------------------------------------;

BSEG

;State Flags - Only one flag on at once 
PreheatState_Flag:      dbit 1
SoakState_Flag: 		dbit 1
RampState_Flag:	 		dbit 1
ReflowState_Flag: 		dbit 1
CooldownState_Flag: 	dbit 1

soak_menu_flag: 		dbit 1
reflow_menu_flag:		dbit 1

;Transition Flag turns on when state is changing, and turns off shortly afterwards
;Use with State flags in logic in order to determine what to do eg. beeps to play when x state is (just recently) on and transition flag is on as well
Transition_Flag: 		dbit 1 

CoolEnoughToOpen_Flag: 	dbit 1
CoolEnoughToTouch_Flag: dbit 1
Cooldowntouch_Flag: 	dbit 1
DoorOpen_Flag: 			dbit 1

mf: 					dbit 1 ;Math Flag for use with math32.inc

Abort_Flag: 			dbit 1
Seconds_flag: 			dbit 1
HalfSecond_Flag:		dbit 1

;-------------------------------------------;
;         Pins and Constant Strings         ;
;-------------------------------------------;

CSEG
;ADC Master/Slave pins
CE_ADC  EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3

;LCD pins
LCD_RS  EQU P1.2
LCD_RW  EQU P1.3
LCD_E   EQU P1.4
LCD_D4  EQU P3.2
LCD_D5  EQU P3.3
LCD_D6  EQU P3.4
LCD_D7  EQU P3.5

SOUND_OUT EQU P3.7 ;Temp value, modify to whatever pin is attached to speaker
POWER     EQU P2.4
;Pushbutton pins
Button_1      EQU P0.1 ;1
Button_2      EQU P0.3 ;2
Button_3      EQU P0.5 ;3
DONE_BUTTON   EQU P2.5 ;4
BOOT_BUTTON   EQU P4.5 ;5

;Main Menu Strings
Temp_Message:	db '>TEMP', 0
State_Message:	db '>STATE', 0
Time_Message:	db '>TIME', 0
TEST_1:			db '<"DONE" TO EXIT>', 0
soak_message:	db ' Soak         B1', 0
reflow_message:	db ' Reflow       B2', 0
choose_soak:	db '>Soak         B1', 0
choose_reflow:	db '>Reflow       B2', 0
temp_soak:		db 'Soak Temp:', 0
temp_reflow:	db 'Reflow Temp:', 0
time_soak:		db 'Soak Time:', 0
time_reflow:	db 'Reflow Time:', 0
no_state:		db 'NO STATE CHOSEN.'
setTemp_guide:	db 'xxxx deg.C', 0
setTime_guide:	db 'xx:xx MIN/SEC', 0

;Runtime Strings           1234567890123456
Runtime_Message:       db 'xx:xx', 0
Current_Temp_Message:  db 'xxxx C', 0
State_Message_Runtime: db 'State: xxxxxxxxx', 0

;State Display Strings     1234567890123456
Off_Display:	  db      'OFF      ', 0
Preheat_Display:  db      'PREHEAT  ', 0
Soak_Display:     db      'SOAK     ', 0
Ramp_Display:     db      'RAMP     ', 0
Reflow_Display:   db      'REFLOW   ', 0
Cooldown_Display: db      'COOLDOWN ', 0
Done_Display:     db 	  'DONE     ', 0

;Misc Strings
Abort_String: 	  db 'PROCESS ABORTED', 0

;-------------------------------------------;
;               Include Files               ;
;-------------------------------------------;

$NOLIST
$include(macros.inc) ;Includes LCD_4Bit macros and all other necessary macros
$LIST

$NOLIST
$include(math32.inc) ; for math functions
$LIST

$NOLIST
$include(LCD_4Bit.inc)
$LIST

;-------------------------------------------;
;            SPI Initialization             ;
;-------------------------------------------;

INIT_SPI:
	setb MY_MISO ; Make MISO an input pin
	clr MY_SCLK ; Mode 0,0 default
	ret
DO_SPI_G:
	mov R1, #0 ; Received byte stored in R1
	mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
	mov a, R0 ; Byte to write is in R0
	rlc a ; Carry flag has bit to write
	mov R0, a
	mov MY_MOSI, c
	setb MY_SCLK ; Transmit
	mov c, MY_MISO ; Read received bit
	mov a, R1 ; Save received bit in R1
	rlc a
	mov R1, a
	clr MY_SCLK
	djnz R2, DO_SPI_G_LOOP
	ret
;-------------------------------------------;
;        Serial Port Initialization         ;
;-------------------------------------------;

; Configure the serial port and baud rate using timer 1
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, or risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can safely proceed with the configuration
	clr	TR1
	anl	TMOD, #0x0f
	orl	TMOD, #0x20
	orl	PCON,#0x80
	mov	TH1,#T1LOAD
	mov	TL1,#T1LOAD
	setb TR1
	mov	SCON,#0x52
    ret

;-------------------------------------------;
;     Converting Voltage to Temperature     ;
;-------------------------------------------;
ConvertNum:
    mov y+0,Result
    mov y+1,Result+1
    mov y+2,#0
    mov y+3,#0
    load_x(37); 1/(41e^-6 * 330) ~= 74
    lcall mul32
    lcall hex2bcd
    ret  
;-------------------------------------------;
;         Timer 0 Initialization            ;
;-------------------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret
	
;-------------------------------------------;
;       	   Timer 0 ISR    		        ;
;-------------------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; In mode 1 we need to reload the timer.
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	jb Transition_Flag, Transitionbeep
	jb DoorOpen_Flag, Doorbeep
	jb CoolEnoughToTouch_Flag, Touchbeep		
	reti
Transitionbeep:
	Beep(#1, #0)
	clr Transition_Flag
	reti
Doorbeep:
	Beep(#1, #1)
	clr DoorOpen_Flag
	reti
Touchbeep:
	Beep(#6, #0)
	clr CoolEnoughToTouch_Flag
	reti
	
;-------------------------------------------;
;         Timer 2 Initializiation           ;
;-------------------------------------------; 
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret
;-------------------------------------------;
;                Timer 2 ISR                ;
;-------------------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1
	
Inc_Done:
	;Check half second
	mov a, Count1ms+0
	cjne a, #low(500), ContISR2 ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(500), ContISR2
	setb HalfSecond_Flag

ContISR2:
	; Check if a second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done_redirect ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done_redirect
	sjmp SecondPassed

Timer2_ISR_done_redirect:
ljmp Timer2_ISR_done

;Increment seconds bcd value every second, and minute every minute, resetting seconds
SecondPassed:
	; 1 second has passed.  Set a flag so the main program knows
	setb Seconds_flag ; Let the main program know a second had passed
	setb HalfSecond_Flag
	jnb SoakState_Flag, check_reflow
	sjmp soak_timer
check_reflow:
	jnb ReflowState_Flag, ContinueISR
	;increment reflow
	mov a, ReflowTime_Secs
	add a,#0x01
	da a
	mov ReflowTime_Secs,a
	cjne a,#0x60, ContinueISR
	mov a,#0x00
	da a
	mov ReflowTime_Secs,a
	mov ReflowTime_Mins,a
	add a,#0x01
	da a
	mov a, ReflowTime_Mins
	sjmp ContinueISR
soak_timer:
	mov a, SoakTime_Secs
	add a,#0x01
	da a
	mov SoakTime_Secs,a
	cjne a,#0x60, ContinueISR
	mov a,#0x00
	da a
	mov SoakTime_Secs,a
	mov SoakTime_Mins,a
	add a,#0x01
	da a
	mov a, SoakTime_Mins
ContinueISR:	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a

	; Increment the seconds counter
	mov a, Secs_BCD
	add a,#0x01
	da a
	mov Secs_BCD, a
	cjne a,#0x60,Timer2_ISR_done
	mov a,#0x00
	da a
	mov Secs_BCD, a
	mov a, Mins_BCD
	add a,#0x01
	da a
	mov Mins_BCD,a
Timer2_ISR_done:
	pop psw
	pop acc
	reti
  
;-------------------------------------------;
;                Main Code                  ;
;-------------------------------------------;
MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    mov PMOD, #0 ; Configure all ports in bidirectional mode
    setb CE_ADC ;ADC enabled when bit is cleared, so start disabled
    
    ;Initialize Serial Port Interface, and LCD
    lcall InitSerialPort
    lcall INIT_SPI
    lcall LCD_4BIT
    lcall Timer2_Init
    lcall Timer0_Init
    
    ;Set Flag Initial Values
    clr Abort_Flag
    clr SoakState_Flag
    clr RampState_Flag
    clr ReflowState_Flag
    clr CooldownState_Flag
    setb PreheatState_Flag ;Set Preheat flag to 1 at power on (it won't start preheating until it gets to that loop via Start button)
    
    clr Transition_Flag
    clr mf
    clr CoolEnoughToOpen_Flag
	clr CoolEnoughToTouch_Flag
	clr soak_menu_flag
	clr reflow_menu_flag
    
    ;Set Presets
    mov BCD_soak_temp, 		#0x40
	mov BCD_soak_temp+1, 	#0x01
	mov BCD_reflow_temp, 	#0x19
	mov BCD_reflow_temp+1,	#0x02
	
	mov BCD_soak_time, 		#0x00
	mov BCD_soak_time+1,	#0x01
	mov BCD_reflow_time, 	#0x30
	mov BCD_reflow_time+1,	#0x00
	
	mov Mins_BCD, #0x00
	mov Secs_BCD, #0x00 
	
	;Zero the runtime of the reflow state
	mov ReflowTime_Secs, #0x00
	mov	ReflowTime_Mins, #0x00 
	mov SoakTime_Secs, #0x00
	mov	SoakTime_Mins, #0x00
	
	;Give temp an initial value so it doesn't auto-abort because of an unknown
	mov Temperature+0, #0x00
	mov Temperature+1, #0x00
	mov Temperature+2, #0x00
       
MenuLoop:
    ;Display Initial Screen (Also clear it because it'll have other screens going to it)
    Set_Cursor(1,1)
	Send_Constant_String(#Temp_Message)
	Set_Cursor(1,11)
	Send_Constant_String(#State_Message)
	Set_Cursor(1,6)
	Send_Constant_String(#Time_Message)

	;Check for each menu button
	;B1 - Go to state change menu
	;B2 - Go to Time change menu
	;B3 - Go to Temp change menu
	;B4 - Initialize the program with the given settings (note: we should perhaps set default settings ie ones we'll be using for our specific reflow)
StateMenu_Checker:
	push_button(#1)
	jz TimeMenu_Checker ;State button (B1) not pressed, so jump to check Time button (B2)
	ljmp StateMenu ;If State button (B1) pressed, go to StateMenu
		
TimeMenu_Checker:
	push_button(#2)
	jz TempMenu_Checker ;Time button (B2) not pressed, so jump to check Temp button (B3)
	ljmp TimeMenu ;If Time button (B2) pressed, go to TimeMenu
	
TempMenu_Checker:
	push_button(#3)
	jz Initialize_Checker ;Temp button (B3) not pressed, so jump to check the initialize button (B4)
	ljmp TempMenu ;If Temp button (B3) pressed, go to TempMenu
	
Initialize_Checker:
	push_button(#4)
	jz Back2Menu ;Done button (B4) not pressed, so loop back to beginning of menuloop and check buttons again
	ljmp ProgramRun ;If Done button (B4) pressed, go to initialization (ProgramRun) of Heating Profile
	
Back2Menu:
	ljmp MenuLoop
;------------------------------------------------------------------------------;
	
;------------------------------------------------------------------------------;
StateMenu:
	;Display State and clear old screen
	;If B1 pressed, change state between Reflow/Soak
	;If B4 pressed, go back to main menu loop
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	Set_Cursor(1,1)
	Send_Constant_String(#soak_message)
	Set_Cursor(2,1)
	Send_Constant_String(#reflow_message)	
	
StateMenu_Loop: ;Internal loop so the screen isn't constantly cleared
	push_button(#4)
	jz StateMenu_Loop_P2
	ljmp BackToMain
	
StateMenu_Loop_P2:
	push_button(#1)
	jz StateMenu_loop_P5
	clr reflow_menu_flag
	setb soak_menu_flag
	
StateMenu_loop_P5:
	push_button(#2)
	jz StateMenu_Loop_P6
	clr soak_menu_flag
	setb reflow_menu_flag

	;jump if soak flag not set
	;display arrow at soak
	;go to StateMenu_Loop
StateMenu_Loop_P6:	
	jnb soak_menu_flag, StateMenu_Loop_P3
	Set_Cursor(2,1)
	Send_Constant_String(#reflow_message)
	Set_Cursor(1,1)
	Send_Constant_String(#choose_soak)
	ljmp StateMenu_Loop
	
	;jump if reflow flag not set
	;display arrow at reflow
	;go to StateMenu_Loop
StateMenu_Loop_P3:
	jnb reflow_menu_flag, StateMenu_loop_P4
	Set_Cursor(1,1)
	Send_Constant_String(#soak_message)
	Set_Cursor(2,1)
	Send_Constant_String(#choose_reflow)
	ljmp StateMenu_Loop
	
StateMenu_loop_P4:
	ljmp StateMenu_Loop
;------------------------------------------------------------------------------;	
	
;------------------------------------------------------------------------------;
TimeMenu:
	;Display Time
	;If B1 pressed, increment time BCD value (we'll need to check what state's time is being changed via flag maybe)
	;If B2 held and B1 pressed, decrement value instead of increment
	;If B3 held and B1 pressed, increment (or decrement if B2 held too) by 10
	;If B4 pressed, go back to main menu loop
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TimeMenu_Loop: ;Internal loop so the screen isn't constantly cleared
	push_button(#4)
	jz TimeMenu_Loop_P2
	ljmp BackToMain
	
TimeMenu_Loop_P2:
	jnb soak_menu_flag, TimeMenu_Loop_P3
	Set_Cursor(1,1)
	Send_Constant_String(#time_soak)
	Set_Cursor(2,1)
	Send_Constant_String(#setTime_guide)
	ljmp set_time_soak
	
TimeMenu_Loop_P3:
	jnb reflow_menu_flag, TimeMenu_Loop_P4
	Set_Cursor(1,1)
	Send_Constant_String(#time_reflow)
	Set_Cursor(2,1)
	Send_Constant_String(#setTime_guide)
	ljmp set_time_reflow

TimeMenu_Loop_P4:
	Set_Cursor(2,1)
	Send_Constant_String(#no_state)
	ljmp TimeMenu_Loop
	
set_time_soak:

sTime_s_main:
	push_button(#4)
	jz sTime_s_L1
	ljmp BackToMain
	
sTime_s_L1:
sTime_s_increment:
	push_button(#1)
	jz sTime_s_write_BCD
	mov a, BCD_soak_time
	add a, #0x01
	da a
	mov BCD_soak_time, a
	cjne a, #0x31, sTime_s_write_BCD
	mov BCD_soak_time, #0x00
	
sTime_s_write_BCD:	
	Set_Cursor(2,1)
	Display_BCD(BCD_soak_time+1)
	Set_Cursor(2,4)
	Display_BCD(BCD_soak_time)
	ljmp sTime_s_main
		
set_time_reflow:

sTime_r_main:
	push_button(#4)
	jz sTime_r_L1
	ljmp BackToMain
	
sTime_r_L1:
sTime_r_increment:
	push_button(#1)
	jz sTime_r_write_BCD
	mov a, BCD_reflow_time
	add a, #0x01
	da a
	mov BCD_reflow_time, a
	cjne a, #0x60, sTime_r_increment_1
	mov BCD_reflow_time, #0x00
	mov BCD_reflow_time+1, #0x01
sTime_r_increment_1:	
	cjne a, #0x01, sTime_r_write_BCD
	mov BCD_reflow_time+1, #0x00
	mov BCD_reflow_time, #0x30
	
sTime_r_write_BCD:	
	Set_Cursor(2,1)
	Display_BCD(BCD_reflow_time+1)
	Set_Cursor(2,4)
	Display_BCD(BCD_reflow_time)
	ljmp sTime_r_main
;------------------------------------------------------------------------------;

;------------------------------------------------------------------------------;
TempMenu:
	;Display Time
	;If B1 pressed, increment temp BCD value (we'll need to check what state's temp is being changed via flag maybe)
	;If B2 held and B1 pressed, decrement value instead of increment
	;If B3 held and B1 pressed, increment (or decrement if B2 held too) by 10
	;If B4 pressed, go back to main menu loop
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TempMenu_Loop: ;Internal loop so the screen isn't constantly cleared
	push_button(#4)
	jz TempMenu_Loop_P2
	ljmp BackToMain
	
TempMenu_Loop_P2:
	jnb soak_menu_flag, TempMenu_Loop_P3
	Set_Cursor(1,1)
	Send_Constant_String(#temp_soak)
	Set_Cursor(2,1)
	Send_Constant_String(#setTemp_guide)
	ljmp set_temp_soak
	
TempMenu_Loop_P3:
	jnb reflow_menu_flag, TempMenu_Loop_P4
	Set_Cursor(1,1)
	Send_Constant_String(#temp_reflow)
	Set_Cursor(2,1)
	Send_Constant_String(#setTemp_guide)
	ljmp set_temp_reflow

TempMenu_Loop_P4:
	Set_Cursor(2,1)
	Send_Constant_String(#no_state)
	ljmp TempMenu_Loop	
	
set_temp_soak:

sts_main:
	push_button(#4)
	jz sts_L1
	ljmp BackToMain
	
sts_L1:
sts_increment:
	push_button(#1)
	jz sts_write_BCD
	mov a, BCD_soak_temp
	add a, #0x01
	da a
	mov BCD_soak_temp, a
	cjne a, #0x01, sts_increment_1
	mov BCD_soak_temp, #0x40
	mov BCD_soak_temp+1, #0x01
	ljmp sts_write_BCD
sts_increment_1:	
	cjne a, #0x00, sts_write_BCD
	mov a, BCD_soak_temp+1
	add a, #0x01
	da a
	mov BCD_soak_temp+1, a
	
sts_write_BCD:	
	Set_Cursor(2,1)
	Display_BCD(BCD_soak_temp+1)
	Set_Cursor(2,3)
	Display_BCD(BCD_soak_temp)
	ljmp sts_main
	
set_temp_reflow:	

str_main:
	push_button(#4)
	jz str_L1
	ljmp BackToMain
	
str_L1:
str_increment:
	push_button(#1)
	jz str_write_BCD
	mov a, BCD_reflow_temp
	add a, #0x01
	da a
	mov BCD_reflow_temp, a
	cjne a, #0x36, str_write_BCD
	mov BCD_reflow_temp, #0x19
	
str_write_BCD:	
	Set_Cursor(2,1)
	Display_BCD(BCD_reflow_temp+1)
	Set_Cursor(2,3)
	Display_BCD(BCD_reflow_temp)
	ljmp str_main
;------------------------------------------------------------------------------;

BackToMain:
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ljmp MenuLoop
	
ProgramRun:
	;Clear screen first before displaying runtime, currstate, temp, etc
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	
	setb EA   ; Enable Global interrupts
	
	;Display the program headings (Runtime, State, and Temp at current time)	
	;Display Current runtime on top of LCD, as well as state
	Set_Cursor(1,1)
	Send_Constant_String(#Runtime_Message)
	Set_Cursor(1,10)
	Send_Constant_String(#Current_Temp_Message)
	Set_Cursor(2,1)
	Send_Constant_String(#State_Message_Runtime)		
			
ProgramRun_Loop:
	
	Set_Cursor(1,1)
	Display_BCD(Mins_BCD)
	Set_Cursor(1,4)
	Display_BCD(Secs_BCD)
	
	;CurrTemp
	Read_ADC_Channel(0)
	lcall ConvertNum; converts voltage received to temperature
	
	jnb HalfSecond_Flag, DontPrintTemp
	Set_Cursor(1,10)
	Display_BCD(Temperature+2);upper bits of temp bcd
	Set_Cursor(1,12)
	Display_BCD(Temperature+1);lower bits of temp bcd
	clr HalfSecond_Flag
DontPrintTemp:	
	Set_Cursor(1,10)
	Display_BCD(Temperature+2);upper bits of temp bcd
	Set_Cursor(1,12)
	Display_BCD(Temperature+1);lower bits of temp bcd
	
	;Monitor for abort button (B6) at all times and if pressed, set Abort_Flag
	;Also run MonitorTemp macro, which sets the abort flag under certain conditions
	;MonitorTemp(Temperature) ;Will work once temperature is working
	;If Start/Done button is pressed, immediately abort, as we don't need to check other abort conditions
	;MonitorTemp(Temperature+2,Temperature+1)
	push_button(#4)
	jz CheckAbortFlag
	sjmp Abortx
	
CheckAbortFlag:
	jb Abort_Flag, Abortx
	sjmp DontAbort
	
Abortx:
	ljmp Abort ;Using this to jump to abort from here since there is lots of code in between
	
DontAbort:
	clr seconds_flag ;keep clearing the seconds flag so it doesn't accidentally incrmeent seconds more than once
	;Serially send the current temp so that python can do a stripchart	
	;Wait_Milli_Seconds(#250)
	;Wait_Milli_Seconds(#250);wait half a second
	;Send_BCD(Temperature+2)
	;Send_BCD(Temperature+1)
	;mov a, #'.'
	;lcall putchar
	;Send_BCD(Temperature+0)
	;mov a, #' '
	;lcall putchar
	;mov a, #'C'
	;lcall putchar
    ;mov a,#'\r'
    ;lcall putchar
    ;mov a,#'\n'
    ;lcall putchar	
	;Here we can check CurrentState flags, IE ReflowState_Flag
	;Depending on the current set state flag, jump to state loops until that state logic is done (ie when reflow state ends, ReflowState_Flag gets set to zero and CooldownState_Flag gets set to 1)
	;State loops do their own checks quickly, and come back to the program run loop, which does the constant temp monitoring/display/spi logic
	jb PreheatState_Flag, DisplayPreheat
	jb SoakState_Flag, DisplaySoak
	jb RampState_Flag, DisplayRamp
	jb ReflowState_Flag, DisplayReflow
	jb CooldownState_Flag, DisplayCooldown_jump
	jb Cooldowntouch_Flag, Cooldowntouch_jump
	ljmp ProgramRun_Loop
	
DisplayCooldown_jump:
	ljmp DisplayCooldown
Cooldowntouch_jump:
	ljmp DisplayCooldowntouch

;Display Done here to bypass the length of jb
;Display current state	
DisplayPreheat:
	Set_Cursor(2,8)
	Send_Constant_String(#Preheat_Display)
	ljmp Preheat ;No need to check flags twice, so after updating display, jump right into the specified state

;See DisplayPreheat above as this is basically the same thing for each state	
DisplaySoak:
	Set_Cursor(2,8)
	Send_Constant_String(#Soak_Display)
	ljmp Soak
	
DisplayRamp:
	Set_Cursor(2,8)
	Send_Constant_String(#Ramp_Display)
	ljmp Ramp
	
DisplayReflow:
	Set_Cursor(2,8)
	Send_Constant_String(#Reflow_Display)
	ljmp Reflow
	
DisplayCooldown:
	Set_Cursor(2,8)
	Send_Constant_String(#Cooldown_Display)
	ljmp Cooldown
	
DisplayCooldowntouch:
	Set_Cursor(2,8)
	Send_Constant_String(#Done_Display)
	ljmp Cooldowntouch

;Run heating logic with SSR until SoakTemp degrees C at ~1-3 C/sec
;If CurrTemp >= SoakTemp, jump to DonePreheating	
Preheat:
	setb POWER
	mov a, BCD_soak_temp ; a = desired temperature
	clr c
	subb a, Temperature+1 ; temp = current temperature
	jc preheat_next
	ljmp ProgramRun_Loop
preheat_next:
	mov a, BCD_soak_temp+1
	clr c
	subb a, Temperature+2
	jz DonePreheating		
	ljmp ProgramRun_Loop

DonePreheating:
	clr PreheatState_Flag
	setb SoakState_Flag
	setb Transition_Flag
 	ljmp ProgramRun_Loop
;Run logic to Maintain temperature at SoakTemp degrees C for SoakTime Seconds
;After soaktime seconds, jump to DoneSoaking

;After CurrTemp >= SoakTemp, turn power off, else turn power on
Soak:
	mov a, BCD_soak_temp
	clr c
	subb a, Temperature+1
	jc soak_next
	sjmp continue_soak
soak_next:
	mov a, BCD_soak_temp+1
	clr c
	cjne a, Temperature+2, power_on
	clr POWER
	sjmp Continue_Soak	
power_on:
	setb POWER
Continue_Soak:
	mov a, BCD_soak_time
	clr c
	subb a, SoakTime_Secs
	jc DoneSoaking	
	ljmp ProgramRun_Loop		
DoneSoaking:
	clr SoakState_Flag
	setb RampState_Flag
	setb Transition_Flag
	ljmp ProgramRun_Loop

;Run logic to heat until ReflowTemp degrees C is reached at ~1-3 C /sec
;After CurrTemp >= ReflowTemp, jump to DoneRamping
Ramp:
	setb POWER
	mov a, BCD_reflow_temp
	clr c
	subb a, Temperature+1
	jc ramp_next
	ljmp ProgramRun_Loop
ramp_next:
	mov a, BCD_reflow_temp+1
	clr c
	subb a, Temperature+2
	jz DoneRamping
	ljmp ProgramRun_Loop
	
DoneRamping:
	clr RampState_Flag
	setb ReflowState_Flag
	setb Transition_Flag
	ljmp ProgramRun_Loop

;Run logic to heat until max temp at some deg/s
;Then logic to run until cooled <= ReflowTemp
;When it cools below ReflowTemp, jump to DoneReflowing
Reflow:
	mov a, BCD_reflow_temp
	clr c
	subb a, Temperature+1
	jc reflow_next
	sjmp continue_reflow
reflow_next:
	mov a, BCD_reflow_temp+1
	clr c
	cjne a, Temperature+2, power_on_reflow
	clr POWER
	sjmp continue_reflow
power_on_reflow:
	setb POWER
continue_reflow:	
	mov a, BCD_reflow_time+1
	jz CheckSecs_Reflowing
	cjne a, ReflowTime_Mins, checksecs
checksecs:
	mov a, ReflowTime_Secs
	cjne a, #0x00, program_jump
	sjmp DoneReflowing	
CheckSecs_Reflowing:
	mov a, BCD_reflow_time ;lower
	clr c
	subb a, ReflowTime_Secs
	jc DoneReflowing
	jz CheckSecs_Reflowing
program_jump:
	ljmp ProgramRun_Loop
	
DoneReflowing:
	clr ReflowState_Flag
	setb CooldownState_Flag
	setb Transition_Flag
	ljmp ProgramRun_Loop

;Run logic to turn oven off and set a 'CoolEnoughToOpen' flag (which will trigger certain beeps) once it is cool enough to open the oven door
;And once it is cool enough to touch, set the 'CoolEnoughToTouch' flag (which triggers other beeps)
Cooldown:
	clr POWER
	mov a, #60
	clr c
	subb a, Temperature+1
	jc cooldown_next
	ljmp ProgramRun_Loop
cooldown_next:
	mov a, Temperature+2
	jz DoneCoolDown
	ljmp ProgramRun_Loop
	
DoneCoolDown:
	clr CooldownState_Flag
	setb Transition_Flag
	setb CoolEnoughToOpen_Flag
	setb Cooldowntouch_Flag
	ljmp ProgramRun_Loop
	
Cooldowntouch:
	mov a, #30
	clr c
	subb a, Temperature+1
	jc cooldowntouch_next
	ljmp ProgramRun_Loop
cooldowntouch_next:
	mov a, Temperature+2
	jz DoneCooldowntouch
	ljmp ProgramRun_Loop
	
DoneCooldowntouch:
	clr Cooldowntouch_Flag
	setb Transition_Flag
	setb CoolEnoughToTouch_Flag
	ljmp ENDLOOP
	
Abort:
	;Program will jump here from ProgramRun: if it does, send command to turn off oven, stopping the program
	;Clear screen first before displaying abort message
	clr POWER
	
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	
	;Aborted
	Set_Cursor(2,1)
	Send_Constant_String(#Abort_String)
	
ENDLOOP:
	sjmp ENDLOOP

END
