; Christian Schroeder
; Hannah Sawiuk
; Jake Osborne
; ELEC 291, Project 1, Reflow Oven Controller

;----------------------------------------------;
; Module:	User_Interface                     ;
;----------------------------------------------;

$MODLP52
org 0000H
   ljmp Main_Program

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

BOOT_BUTTON   equ P4.5
Button_1	  equ P0.1
Button_2	  equ P0.3
Button_3	  equ P0.5
   
dseg at 30H ; This area is for direct access variables
;--->
Result:	ds 2
x:   	ds 4
y:   	ds 4
bcd: 	ds 5
;--->

bseg        ; This area is for one-bit variables
;--->
mf: 	dbit 1
;--->

CSEG

LCD_RS equ P1.2
LCD_RW equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5

$NOLIST
$include(LCD_4bit.inc) 	; A library of LCD related functions and utility macros
$LIST

$NOLIST
$include(math32.inc)	; A library of helpful math functions and utility macros
$LIST

; The following are constant strings that we can send to the LCD_4bit
Temp_Message:	db '>TEMP', 0
State_Message:	db '>STATE', 0
Time_Message:	db '>TIME', 0
Blank_Message:	db ' ', 0
TEST_1:			db '< Boot to EXIT >'
;----------------------------------------------;

;-----------------------;
;  Main_Program:		;
;-----------------------;
Main_Program:
	mov SP, #0x7F ; Set the stack pointer to the begining of idata
    mov PMOD, #0 ; Configure all ports in bidirectional mode
	
	lcall LCD_4BIT
	
LOOP_MAIN:
	Set_Cursor(1,1)
	Send_Constant_String(#Temp_Message)
	Set_Cursor(1,11)
	Send_Constant_String(#State_Message)
	Set_Cursor(1,6)
	Send_Constant_String(#Time_Message)
	
	
	jb Button_1, NEXT1
	Wait_Milli_Seconds(#50)	
	jb Button_1, NEXT1
	jnb Button_1, $
	ljmp STATE_change
NEXT1:	
	jb Button_2, NEXT2
	Wait_Milli_Seconds(#50)	
	jb Button_2, NEXT2
	jnb Button_2, $
	ljmp TIME_change
NEXT2:
	jb Button_3, NEXT3
	Wait_Milli_Seconds(#50)	
	jb Button_3, NEXT3
	jnb Button_3, $
	ljmp TEMP_change
NEXT3:
	
	ljmp LOOP_MAIN
	
go_to_END:
	ljmp finish
;----------------------------------------------;

;----------------------------------------------;

;-----------------------;
;  MISC_SPACE:		    ;
;-----------------------;



;----------------------------------------------;

;----------------------------------------------;

;-----------------------;
;  State_Changes:		;
;-----------------------;

STATE_change:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
SM_cont:
	jb BOOT_BUTTON, SM_ret
	Wait_Milli_Seconds(#50)	
	jb BOOT_BUTTON, SM_ret
	jnb BOOT_BUTTON, $
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp SM_cont
SM_ret:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ret


TIME_change:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TIME_cont:
	jb BOOT_BUTTON, TIME_ret
	Wait_Milli_Seconds(#50)	
	jb BOOT_BUTTON, TIME_ret
	jnb BOOT_BUTTON, $
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp TIME_cont
TIME_ret:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ret

	
TEMP_change:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TEMP_cont:
	jb BOOT_BUTTON, TEMP_ret
	Wait_Milli_Seconds(#50)	
	jb BOOT_BUTTON, TEMP_ret
	jnb BOOT_BUTTON, $
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp TEMP_cont	
TEMP_ret:
	;WriteCommand(#0x28)
	;WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ret
;----------------------------------------------;

finish:
END
