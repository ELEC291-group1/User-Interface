CSEG
; Christian Schroeder
; Hannah Sawiuk
; Jake Osborne
; ELEC 291, Project 1, Reflow Oven Controller
; macros.inc


;-------------------------------------------;
;                Functions                  ;
;-------------------------------------------;
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

;-------------------------------------------;
;                 Macros                    ;
;-------------------------------------------;

;1.
;Purpose: Reads a voltage at x channel of ADC Chip
;Usage: Read_ADC_Channel(x) 
;Return: Returns 10 bit voltage in Result(low) and Result+1(high 2 bits)

Read_ADC_Channel mac
	mov b, #%0
	lcall ?Read_ADC_Channel
endmac


;1.    
?Read_ADC_Channel:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov a, b
	swap a
	anl a, #0F0H
	setb acc.7 ; Single mode (bit 7).
	mov R0, a
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #00000011B ; We need only the two least significant bits
	mov R7, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov a, R1
	mov R6, a ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
	mov Result+1,R7
	mov Result,R6
	ret


;2.
;Purpose: Monitors temperature and stops Oven if too hot. Will be updated as a more multipurpose macro to monitor multiple safety hazards
;Usage: MonitorTemp(x), where x is the BCD temperature in celsius - use in a loop to constantly check the temp passes all the current tests
;Return: No return
MonitorTemp mac
	push AR2
	mov R2,%0
	lcall ?MonitorTemp
	pop AR2
endmac

;2.
;?MonitorTemp:
;	mov a, R2
;	clr c
;	subb a,#MAX_TEMP ;235
;	jnc Abort_mac
	 
			 
;If any unsafe conditions above are met, the program will jump here, and set this flag which will shut down the program in a timer0 interrupt
Abort_mac:
	setb Abort_Flag
	ret
TempMonitorReturn:
	ret

    
;3.
;Purpose: Serially transmits a BCD value to Putty/Serial Port
;Usage: Send_BCD(BCD_val) sends BCD_val serially
;Return: No return
Send_BCD mac
    push ar0
    mov r0, %0
    lcall ?Send_BCD
    pop ar0
endmac
;3.
?Send_BCD:
    push acc    ; Write most significant digit
    mov a, r0
    swap a
    anl a, #0fh
    orl a, #30h
    lcall putchar   ; write least significant digit
    mov a, r0
    anl a, #0fh
    orl a, #30h
    lcall putchar
    pop acc
	ret
;4.
;Purpose: Converts voltage to temperature (use as a periodic update function)
;Usage: Call this function Voltage2Temp() and it will take the 10 bit adc value stored in result and result+1 and use it to update the BCD_temp
;Return: No return, but calling this updates the BCD temp based on the current voltage in the recently read ADC channel
Voltage2Temp mac
	lcall ?Voltage2Temp
endmac

;4.
?Voltage2Temp:
    ;Use math32 functions and voltage -> degrees formula for our thermocouple to convert an input voltage to a temperature BCD   
    ret
    
        

;5.
;Purpose: Beeps with a certain frequency and length
;Usage: Beep(repititions,length) will beep (repetitions) times for (length) milliseconds
;Return: Beeeeep
Beep mac
	push AR2
	mov R2, %0 ;repetitions
	push AR3
	mov R3, %1 ; length
	lcall ?Beep
	pop AR3
	pop AR2
endmac

;5.
?Beep:
	mov a, R2  ;number of repetitions
L1_beep:	
	jnz L2_beep  ; while a > 0, repeat beep
	sjmp done_beep 
L2_beep:
	cpl SOUND_OUT
	cjne R3, #0, long_beep
	Wait_Milli_Seconds(#250)
beep_loop:
	dec a
	sjmp L1_beep
done_beep:
	clr SOUND_OUT
	ret
long_beep:
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	sjmp beep_loop
	
;6.
;Purpose: To read a pushbutton and determine if it is pressed or not
;Usage: push_button(#1) checks if button 1 is pressed
;Return: 1 in a if button is pressed, 0 in a if button is not pressed    
;5 buttons
push_button mac
	push AR2
	mov R2, %0 ;button number
	lcall ?push_button
	pop AR2
endmac

;6.
?push_button:
	cjne R2, #1,check2
	sjmp Button1
check2:
	cjne R2, #2, check3
	sjmp Button2
check3:
	cjne R2, #3, checkdone
	sjmp Button3
checkdone:
	cjne R2, #4, checkboot
	sjmp Donebutton
checkboot:
	cjne R2, #5, done
	sjmp Bootbutton	
done:
	clr a
	ret
Button1:
	jb Button_1 , not_pressed 
	Wait_Milli_Seconds(#50)	
	jb Button_1, not_pressed 
	jnb Button_1, $
	mov a, #1
	ret
Button2:
	jb Button_2 , not_pressed  
	Wait_Milli_Seconds(#50)	
	jb Button_2, not_pressed 
	jnb Button_2, $
	mov a, #1
	ret
Button3:
	jb Button_3 , not_pressed  
	Wait_Milli_Seconds(#50)
	jb Button_3, not_pressed
	jnb Button_3, $
	mov a, #1
	ret
Donebutton:
	jb DONE_BUTTON , not_pressed  
	Wait_Milli_Seconds(#50)	
	jb DONE_BUTTON , not_pressed 
	jnb DONE_BUTTON , $
	mov a, #1
	ret
Bootbutton:
	jb BOOT_BUTTON, not_pressed  
	Wait_Milli_Seconds(#50)	
	jb BOOT_BUTTON, not_pressed 
	jnb BOOT_BUTTON, $
	mov a, #1
	ret	
not_pressed:
	mov a, #0
	ret
	
;7.
Preheat_Abort mac
	push AR2
	mov R2, %0 ;temp lower
	lcall ?Preheat_Abort_1
	pop AR2
endmac
	
?Preheat_Abort_1:
	clr c
	mov a, R2
	subb a, #0x50
	jnc Preheat_Abort_END
	setb Abort_Flag
Preheat_Abort_END:
	ret
