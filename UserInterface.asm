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

DONE_BUTTON   EQU P2.1 ;4
Button_1      EQU P0.1 ;1
Button_2      EQU P0.3 ;2
Button_3      EQU P0.5 ;3
   
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
$include(macros3.inc) ;includes LCD_4bit.inc
;$include(LCD_4bit.inc) 	; A library of LCD related functions and utility macros
$LIST

$NOLIST
$include(math32.inc)	; A library of helpful math functions and utility macros
$LIST

; The following are constant strings that we can send to the LCD_4bit
Temp_Message:	db '>TEMP', 0
State_Message:	db '>STATE', 0
Time_Message:	db '>TIME', 0
Blank_Message:	db ' ', 0
TEST_1:			db '<"DONE" TO EXIT>'
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
	
	push_button(#1)
	jz NEXT1
	lcall STATE_change
NEXT1:	
	push_button(#2)
	jz NEXT2
	lcall TIME_change
NEXT2:
	push_button(#3)
	jz NEXT3
	lcall TEMP_change
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
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
SM_cont:
	push_button(#4)
	jz SM_write
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ljmp SM_ret
SM_write:
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp SM_cont
SM_ret:
	ret
TIME_change:
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TIME_cont:
	push_button(#4)
	jz TIME_write
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ljmp TIME_ret
TIME_write:
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp TIME_cont
TIME_ret:
	ret
TEMP_change:
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
TEMP_cont:
	push_button(#4)
	jz TEMP_write
	WriteCommand(#0x28)
	WriteCommand(#0x0c)
	WriteCommand(#0x01) ;Clears the LCD
	Wait_Milli_Seconds(#10) ;Wait for the clear to finish
	ljmp TEMP_ret
TEMP_write:
	Set_Cursor(2,1)
	Send_Constant_String(#TEST_1)
	ljmp TEMP_cont
TEMP_ret:
	ret
;----------------------------------------------;

finish:
END
