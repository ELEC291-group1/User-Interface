; Christian Schroeder
; Hannah Sawiuk
; Jake Osborne
; ELEC 291, Project 1, Reflow Oven Controller

;----------------------------------------------;
; Module:	User_Interface                       ;
;----------------------------------------------;

$NOLIST
$MODLP52
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

org 0000H
   ljmp MainProgram
   
dseg at 30H ; This area is for direct access variables
;--->

;--->

bseg        ; This area is for one-bit variables
;--->

;--->

;----------------------------------------------;

;-----------------------;
;  Main_Program:		    ;
;-----------------------;




;----------------------------------------------;




;----------------------------------------------;

;-----------------------;
;  Module_Macros:		    ;
;-----------------------;




;----------------------------------------------;


END_LOOP:
	sjmp END_LOOP, $
