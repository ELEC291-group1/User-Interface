cseg
;//////////
;//Macros//
;//////////

$NOLIST
$include(LCD_4bit.inc)
$LIST

;1.
;Purpose: Reads a voltage at x channel of ADC Chip
;Usage: Read_ADC_Channel(x) 
;Return: Returns 10 bit voltage in Result(low) and Result+1(high 2 bits)

;Read_ADC_Channel mac
;	mov b, #%0
;	lcall ?Read_ADC_Channel
;endmac

;/////////////////
;//Macro Details//
;/////////////////


;1.    
;?Read_ADC_Channel:
;	clr CE_ADC
;	mov R0, #00000001B ; Start bit:1
;	lcall DO_SPI_G
;	mov a, b
;	swap a
;	anl a, #0F0H
;	setb acc.7 ; Single mode (bit 7).
;	mov R0, a
;	lcall DO_SPI_G
;	mov a, R1 ; R1 contains bits 8 and 9
;	anl a, #00000011B ; We need only the two least significant bits
;	mov R7, a ; Save result high.
;	mov R0, #55H ; It doesn't matter what we transmit...
;	lcall DO_SPI_G
;	mov a, R1
;	mov R6, a ; R1 contains bits 0 to 7. Save result low.
;	setb CE_ADC
;	mov Result+1,R7
;	mov Result,R6
;	ret


;4.
;Purpose: Monitors temperature and stops Oven if too hot. Will be updated as a more multipurpose macro to monitor multiple safety hazards
;Usage: MonitorTemp(x), where x is the BCD temperature in celsius - use in a loop to constantly check the temp passes all the current tests
;Return: No return
MonitorTemp mac
	push AR2
	push AR3
	mov R2,%0
	mov R3, Curr_Runtime
	lcall ?MonitorTemp
	pop AR2
	pop AR3
endmac


;4.
?MonitorTemp:
	push AR0
	mov a, R2
	cjne a,#235,Not235 ;Check a bunch of temperatures around 235 to make sure it doesn't jump over 235 and keep going
	sjmp Abort
Not235:
	cjne a,#236, Not236
	sjmp Abort
Not236:
	cjne a, #237, Not237
	sjmp Abort
Not237:
	cjne a, #238, CoolTemp
	sjmp Abort
;This is a state where the temperature is below 235C, and where we can check other safety conditions
CoolTemp:
	cjne R3, #60,TempMonitorReturn ;If the current runtime of the reflow is 60s (in later tests, we might need a buffer here like the Not23X labels), perform 50-CurrentTemp
	clr CY ;Clear both carry flags just in case of bugs
	clr AC
	mov R0, a
	mov a, #50
	subb a, R0
	jnb AC,Abort ;AC is from the bit addressable program status word (PSW) register. Basically the bit is set if there is a carry (in subb, in this case)
	pop AR0
	ret			 ;So if AC is not set, that should mean that the temp is <50 degrees C after the 1 minute mark and we should abort the program.	
;If any unsafe conditions above are met, the program will jump here, and set this flag which will shut down the program in a timer0 interrupt
Abort:
	setb shut_down_flag
	pop AR0
	ret
TempMonitorReturn:
	clr shut_down_flag
	ret
;------------------;	
; Push button macro;
;------------------;
	
push_button mac
	push AR2
	mov R2, %0 ;button number
	lcall ?push_button
	pop AR2
endmac
	
?push_button:
	cjne R2, #1,check2
	sjmp Button1
check2:
	cjne R2, #2, check3
	sjmp Button2
check3:
	cjne R2, #3, check_done
	sjmp Button3
check_done:
	cjne R2, #4, not_pressed
	sjmp DONE
Button1:
	jb Button_1 , not_pressed 
	Wait_Milli_Seconds(#50)	
	jb Button_1, not_pressed 
	jnb Button_1, $
	sjmp pressed
	
Button2:
	jb Button_2 , not_pressed  
	Wait_Milli_Seconds(#50)	
	jb Button_2, not_pressed 
	jnb Button_2, $
	sjmp pressed
	
Button3:
	jb Button_3 , not_pressed  
	Wait_Milli_Seconds(#50)
	jb Button_3, not_pressed
	jnb Button_3, $
	sjmp pressed
	
DONE:
	jb DONE_BUTTON , not_pressed  
	Wait_Milli_Seconds(#50)	
	jb DONE_BUTTON, not_pressed 
	jnb DONE_BUTTON, $
	sjmp pressed
		
not_pressed:
	mov a, #0
	ret
pressed:
	mov a, #1
	ret
	
end
