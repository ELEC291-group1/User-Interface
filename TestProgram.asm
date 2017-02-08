; Christian Schroeder
; Hannah Sawiuk
; Jake Osborne
; ELEC 291, Project 1, Reflow Oven Controller
; Main file
$MODLP52

org 0x0000
   ljmp MainProgram

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
;/////////////////////////////////////


;//////////
;Constants/
;//////////

MAX_TEMP equ 230 
CLK  equ 22118400
BAUD equ 115200
T1LOAD equ (0x100-(CLK/(16*BAUD)))
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))   

;//////////
;Variables/
;//////////

DSEG at 30H

Result: 			ds 2
bcd: 				ds 5 ;Temperature in degrees
Curr_Runtime: 		ds 5
x: 					ds 4
y: 					ds 4
BCD_temp:			ds 2
BCD_soak_temp:		ds 2
BCD_reflow_temp:	ds 2	
BCD_soak_time:		ds 2
BCD_reflow_time:	ds 2	


;///////////////
;////Flags//////
;///////////////

BSEG

;State Flags - Only one flag on at once 
PreheatState_Flag: dbit 1
SoakState_Flag: 		dbit 1
RampState_Flag:	 		dbit 1
ReflowState_Flag: 		dbit 1
CooldownState_Flag: 	dbit 1

soak_menu_flag: 		dbit 1
reflow_menu_flag:		dbit 1

;Transition Flag turns on when state is changing, and turns off shortly afterwards
;Use with State flags in logic in order to determine what to do eg. beeps to play when x state is (just recently) on and transition flag is on as well
Transition_Flag: dbit 1 

CoolEnoughToOpen_Flag: dbit 1
CoolEnoughToTouch_Flag: dbit 1

;Math Flag for use with math32.inc
mf: dbit 1 

Abort_Flag: dbit 1

;/////////////////
;Pins and strings/
;/////////////////

CSEG
;ADC Master/Slave pins
CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3

;LCD pins
LCD_RS equ P1.2
LCD_RW equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5

SOUND_OUT equ p0.0 ;Temp value, modify to whatever pin is attached to speaker

;Pushbutton pins
Button_1      EQU P0.1 ;1
Button_2      EQU P0.3 ;2
Button_3      EQU P0.5 ;3
DONE_BUTTON   EQU P2.5 ;4

;///////////////
;Include Files//
;///////////////

$NOLIST
$include(macros.inc) ;Includes LCD_4Bit macros and all other necessary macros
$LIST

$NOLIST
$include(math32.inc) ; for math functions
$LIST

$NOLIST
$include(LCD_4Bit.inc)
$LIST

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


;///////////////////
;SPI Initialization/
;///////////////////

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

;///////////////////////////
;Serial Port Initialization/
;///////////////////////////

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
  

;------------------------------------------------------------------------------;
;/////////////
;///MAIN//////
;///////CODE//
;/////////////
   
MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    mov PMOD, #0 ; Configure all ports in bidirectional mode
    setb CE_ADC ;ADC enabled when bit is cleared, so start disabled
    
    ;Initialize Serial Port Interface, and LCD
    lcall InitSerialPort
    lcall INIT_SPI
    lcall LCD_4BIT
    
    ;Set Flag Initial Values
	
	clr soak_menu_flag
	clr reflow_menu_flag
	
	mov BCD_soak_temp, 		#0x40
	mov BCD_soak_temp+1, 	#0x01
	mov BCD_reflow_temp, 	#0x19
	mov BCD_reflow_temp+1,	#0x02
	
	mov BCD_soak_time, 		#0x00
	mov BCD_soak_time+1,	#0x01
	mov BCD_reflow_time, 	#0x30
	mov BCD_reflow_time+1,	#0x00
	
    clr Abort_Flag
    clr SoakState_Flag
    clr RampState_Flag
    clr ReflowState_Flag
    clr CooldownState_Flag
    setb PreheatState_Flag ;Set Preheat flag to 1 at power on (it won't start preheating until it gets to that loop via Start button)
       
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
	
ProgramRun_Loop:
	;Display Current runtime on top of LCD, as well as state
	;Display BCD converted Current_Temp on bottom of LCD
	;Monitor for abort button (B6) at all times and if pressed, set Abort_Flag
	;Also run MonitorTemp macro, which sets the abort flag under certain conditions
;	MonitorTemp(bcd)
	jb Abort_Flag,Abort
	
	;Serially send the current temp so that python can do a stripchart
	
	;Here we can check CurrentState flags, IE ReflowState_Flag
	;Depending on the current set state flag, jump to state loops until that state logic is done (ie when reflow state ends, ReflowState_Flag gets set to zero and CooldownState_Flag gets set to 1)
	;State loops do their own checks quickly, and come back to the program run loop, which does the constant temp monitoring/display/spi logic
	jb PreheatState_Flag,Preheat
	jb SoakState_Flag,Soak
	jb RampState_Flag,Ramp
	jb ReflowState_Flag,Reflow
	jb CooldownState_Flag,Cooldown
	
	ljmp ProgramRun_Loop
	
Preheat:
	;Run heating logic with SSR until SoakTemp degrees C at ~1-3 C/sec
	;If CurrTemp >= SoakTemp, jump to DonePreheating
	ljmp ProgramRun_Loop

DonePreheating:
	clr PreheatState_Flag
	setb SoakState_Flag
 	ljmp ProgramRun_Loop
Soak:
	;Run logic to Maintain temperature at SoakTemp degrees C for SoakTime Seconds
	;After soaktime seconds, jump to DoneSoaking
	ljmp ProgramRun_Loop
	
DoneSoaking:
	clr SoakState_Flag
	setb RampState_Flag
	ljmp ProgramRun_Loop

Ramp:
	;Run logic to heat until ReflowTemp degrees C is reached at ~1-3 C /sec
	;After CurrTemp >= ReflowTemp, jump to DoneRamping
	ljmp ProgramRun_Loop
	
DoneRamping:
	clr RampState_Flag
	setb ReflowState_Flag
	ljmp ProgramRun_Loop

Reflow:
	;Run logic to heat until max temp at some deg/s
	;Then logic to run until cooled <= ReflowTemp
	;When it cools below ReflowTemp, jump to DoneReflowing
	ljmp ProgramRun_Loop
	
DoneReflowing:
	clr ReflowState_Flag
	setb CooldownState_Flag
	ljmp ProgramRun_Loop

Cooldown:
	;Run logic to turn oven off and set a 'CoolEnoughToOpen' flag (which will trigger certain beeps) once it is cool enough to open the oven door
	;And once it is cool enough to touch, set the 'CoolEnoughToTouch' flag (which triggers other beeps)
	ljmp ProgramRun_Loop
	

Abort:
	;Program will jump here from ProgramRun: if it does, send command to turn off oven, stopping the program

END
