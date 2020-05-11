                                          ; a3_template.asm
; CSC 230 - Summer 2018
; 
; Starter code for A3.
;
; B. Bird - 07/01/2018

.include "lcd_function_defs.inc"

; Stack pointer and SREG registers (in data space)
.equ SPH_DS = 0x5E
.equ SPL_DS = 0x5D
.equ SREG_DS = 0x5F

; Initial address (16-bit) for the stack pointer
.equ STACK_INIT = 0x21FF

; Definitions for the analog/digital converter (ADC)
.equ ADCSRA_DS	= 0x7A ; Control and Status Register A
.equ ADCSRB_DS	= 0x7B ; Control and Status Register B
.equ ADMUX_DS	= 0x7C ; Multiplexer Register
.equ ADCL_DS	= 0x78 ; Output register (high bits)
.equ ADCH_DS	= 0x79 ; Output register (low bits)

; Definitions for button values from the ADC
; Some boards may use the values in option B
; The code below used less than comparisons so option A should work for both
; Option A (v 1.1)
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352
; Option B (v 1.0)
.equ ADC_BTN_RIGHT = 0x032
.equ ADC_BTN_UP = 0x0C3
.equ ADC_BTN_DOWN = 0x17C
.equ ADC_BTN_LEFT = 0x22B
.equ ADC_BTN_SELECT = 0x316
.equ ADC_MAX = 0x03FF

; Definitions of the special register addresses for timer 2 (in data space)
.equ ASSR_DS = 0xB6
.equ OCR2A_DS = 0xB3
.equ OCR2B_DS = 0xB4
.equ TCCR2A_DS = 0xB0
.equ TCCR2B_DS = 0xB1
.equ TCNT2_DS  = 0xB2
.equ TIFR2_DS  = 0x37
.equ TIMSK2_DS = 0x70

.equ DELAY_ITERATIONS = 200000

.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp main_begin
	
; Add interrupt handlers for timer interrupts here. See Section 14 (page 101) of the datasheet for addresses.
.org 0x001e
	jmp TIMER2_OVERFLOW_ISR 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; According to the datasheet, the last interrupt vector has address 0x0070, so the first
; "unreserved" location is 0x0072
.org 0x0072
main_begin:

	; Initialize the stack
	ldi r16, high(STACK_INIT)
	sts SPH_DS, r16
	ldi r16, low(STACK_INIT)
	sts SPL_DS, r16
	
	; Set up the ADC
	; Set up ADCSRA (ADEN = 1, ADPS2:ADPS0 = 111 for divisor of 128)
	ldi	r16, 0x87
	sts	ADCSRA_DS, r16
	
	; Set up ADCSRB (all bits 0)
	ldi	r16, 0x00
	sts	ADCSRB_DS, r16
	
	; Set up ADMUX (MUX4:MUX0 = 00000, ADLAR = 0, REFS1:REFS0 = 1)
	ldi	r16, 0x40
	sts	ADMUX_DS, r16
	
	; Initialize the LCD
	call lcd_init
	
	; Initialize OVERFLOW_INTERRUPT_COUNTER to 0
	ldi r16, 0
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	call TIMER2_SETUP ; Set up timer 2 control registers (function below)
	;sei ; Set the I flag in SREG to enable interrupt processing
	cli
	ldi r16, 1
	sts stop_or_not, r16
	
	call display_time
	call set_initial_char
	call set_initial_store
	call put_digit
	
;wait for adc	
button_press:

	lds YH, high(ADC_MAX)
	lds YL, low(ADC_MAX)

main_loop:
	; Start an ADC conversion

	; Set the ADSC bit to 1 in the ADCSRA register to start a conversion
	lds	r16, ADCSRA_DS
	ori	r16, 0x40
	sts	ADCSRA_DS, r16
	
	; Wait for the conversion to finish
wait_for_adc:
	lds		r16, ADCSRA_DS
	andi	r16, 0x40
	brne	wait_for_adc
	
	call short_delay
	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL_DS
	lds	XH, ADCH_DS

	cp YL, XL
	cpc YH, XH
	brsh move_and_wait
	brlo button
	 
move_and_wait:
	mov YL, XL
	mov YH, XH
	rjmp main_loop
	
button:
	ldi	r20, low(ADC_BTN_RIGHT)
	ldi	r21, high(ADC_BTN_RIGHT)
	cp	YL, r20 ; Low byte
	cpc	YH, r21 ; High byte
	brlo right
		
	ldi	r20, low(ADC_BTN_UP)
	ldi	r21, high(ADC_BTN_UP)
	cp	YL, r20 ; Low byte
	cpc	YH, r21 ; High byte
	brlo up 

	ldi	r20, low(ADC_BTN_DOWN)
	ldi	r21, high(ADC_BTN_DOWN)
	cp	YL, r20 ; Low byte
	cpc	YH, r21 ; High byte
	brlo down 
	
	ldi	r20, low(ADC_BTN_LEFT)
	ldi	r21, high(ADC_BTN_LEFT)
	cp	YL, r20 ; Low byte
	cpc	YH, r21 ; High byte
	brlo left

	ldi	r20, low(ADC_BTN_SELECT)
	ldi	r21, high(ADC_BTN_SELECT)
	cp	YL, r20 ; Low byte
	cpc	YH, r21 ; High byte
	brlo select 

	brsh button_press ; If the ADC value was above the threshold, no button was pressed (so try again)

right:
	rjmp after_button
	
up:
	call STRCPY_PM
	call STRCPY_PM2
	call put_second_line
	rjmp after_button

down:
	call set_initial_store
	call delete_line2
	
	rjmp after_button 

left:
	cli
	call set_initial_char
	call put_digit
	rjmp after_button
	
select:
	lds r16, SREG_DS
	cpi r16, 0x80
	brsh set_no_i
	sei
	rjmp after_button 
set_no_i:
	cli
	rjmp after_button

	lds YH, high(ADC_MAX)
	lds YL, low(ADC_MAX)

after_button:
	; Start an ADC conversion
	; Set the ADSC bit to 1 in the ADCSRA register to start a conversion
	lds	r16, ADCSRA_DS
	ori	r16, 0x40
	sts	ADCSRA_DS, r16
	
	; Wait for the conversion to finish
wait_for_adc_2:
	lds		r16, ADCSRA_DS
	andi	r16, 0x40
	brne	wait_for_adc_2
	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL_DS
	lds	XH, ADCH_DS

	cp XL, YL
	cpc XH, YH
	brlo after_button

	rjmp button_press

	
time_loop:

	;call increment_time
	;call put_digit
	;call short_delay
	rjmp time_loop
	
	
stop:
	rjmp stop
	
	
; TIMER2_SETUP()
; Set up the control registers for timer 2.
TIMER2_SETUP:
	push r16	
	ldi r16, 0x00
	sts TCCR2A_DS, r16
	ldi r16, 0x06
	sts TCCR2B_DS, r16
	ldi r16, 0x01
	sts TIMSK2_DS, r16
	sts TIFR2_DS, r16
		
	pop r16
	ret


TIMER2_OVERFLOW_ISR:
	
	push r16
	lds r16, SREG_DS ; Load the value of SREG into r16
	push r16 ; Push SREG onto the stack
	push r17
	push r18
	
	lds r16, OVERFLOW_INTERRUPT_COUNTER
	lds r17, stop_or_not
	add r16, r17
	
	cpi r16, 24
	brne timer2_isr_done

	; If 24 interrupts have occurred
	call increment_time
	call put_digit
	
	clr r16
	
	
timer2_isr_done:


	; Store the overflow counter back to memory
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	
	pop r18
	pop r17
	; The next stack value is the value of SREG
	pop r16 ; Pop SREG into r16
	sts SREG_DS, r16 ; Store r16 into SREG
	; Now pop the original saved r16 value
	pop r16

	reti ; Return from interrupt
	

short_delay:
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	ldi r16, low(DELAY_ITERATIONS)
	ldi r17, byte2(DELAY_ITERATIONS)
	ldi r18, byte3(DELAY_ITERATIONS)
	ldi r19, byte4(DELAY_ITERATIONS)
delay_loop:
	ldi r20, 0x01
	ldi r21, 0x00
	sub r16, r20
	sbc r17, r21
	sbc r18, r21
	sbc r19, r21
	brne delay_loop
	
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	ret

delete_line2:
	push r16
	push r17
	push YL
	push YH
	
	
	ldi YL, low(LINE_TWO)
	ldi YH, high(LINE_TWO)

	clr r17
delete_loop:
	ldi r16, ' '
	st Y+, r16
	inc r17
	cpi r17, 16
	brlo delete_loop
	
	;display LCD
	ldi r16, 1 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	ldi r16, high(LINE_TWO)
	push r16
	ldi r16, low(LINE_TWO)
	push r16
	call lcd_puts
	pop r16
	pop r16
	
	pop YH
	pop YL
	pop r17
	pop r16
	ret


	
	
STRCPY_PM:
	push r16
	push XL
	push XH
	push YL
	push YH
	
	ldi YL, low(STORE_ARRAY1)
	ldi YH, high(STORE_ARRAY1)
	
	ldi XL, low(STORE_ARRAY2)
	ldi XH, high(STORE_ARRAY2)
	
	
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	
	pop YH
	pop YL
	pop XH
	pop XL
	pop r16
	ret
	
STRCPY_PM2:
	push r16
	push XL
	push XH
	push YL
	push YH
	
	ldi YL, low(STORE_ARRAY2)
	ldi YH, high(STORE_ARRAY2)
	
	ldi XL, low(TIME_ARRAY)
	ldi XH, high(TIME_ARRAY)
	
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	ld r16, X+
	st Y+, r16
	
	pop YH
	pop YL
	pop XH
	pop XL
	pop r16
	ret
	
put_second_line:
	push r16
	push XL
	push XH
	push YL
	push YH

	ldi XL, low(STORE_ARRAY1)
	ldi XH, high(STORE_ARRAY1)
	
	ldi YL, low(LINE_TWO)
	ldi YH, high(LINE_TWO)
	
	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	st Y+, r16

	ldi r16, ':'
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	 
	ldi r16, 0x20 ;' '
	st Y+, r16
	
	ldi r16, 0x20 ;' '
	st Y+, r16

	ldi XL, low(STORE_ARRAY2)
	ldi XH, high(STORE_ARRAY2)
	
	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	st Y+, r16

	ldi r16, ':'
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ldi r16, '.'
	st Y+, r16
	  
	ld r16, X+
	st Y+, r16
	
	ldi r16, 0
	st Y+, r16
	
	;display LCD
	ldi r16, 1 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	ldi r16, high(LINE_TWO)
	push r16
	ldi r16, low(LINE_TWO)
	push r16
	call lcd_puts
	pop r16
	pop r16
	
	pop YH
	pop YL
	pop XH
	pop XL
	pop r16
	ret
	
put_digit:
	push r16
	push XL
	push XH
	push YL
	push YH
	
	ldi XL, low(TIME_ARRAY)
	ldi XH, high(TIME_ARRAY)
	
	ldi YL, low(LINE_ONE)
	ldi YH, high(LINE_ONE)

	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	st Y+, r16

	ldi r16, ':'
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ldi r16, '.'
	st Y+, r16
	
	ld r16, X+
	st Y+, r16
	
	ldi r16, ' '
	st Y+, r16
	
	ldi r16, ' '
	st Y+, r16
	
	ldi r16, ' '
	st Y+, r16
	
	ldi r16, 0
	st Y+, r16
	
	;display LCD
	ldi r16, 0 ; Row number
	push r16
	ldi r16, 6 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	ldi r16, high(LINE_ONE)
	push r16
	ldi r16, low(LINE_ONE)
	push r16
	call lcd_puts
	pop r16
	pop r16
	
	pop YH
	pop YL
	pop XH
	pop XL
	pop r16
	ret
	
display_time:
	push r16
	push YL
	push YH
	
	ldi YL, low(LINE_ONE)
	ldi YH, high(LINE_ONE)

	ldi r16, 'T'
	st Y+, r16
	ldi r16, 'i'
	st Y+, r16
	ldi r16, 'm'
	st Y+, r16
	ldi r16, 'e'
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	
	; Add a null terminator
	ldi r16, 0
	st Y+, r16
	
	;display LCD
	ldi r16, 0 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	ldi r16, high(LINE_ONE)
	push r16
	ldi r16, low(LINE_ONE)
	push r16
	call lcd_puts
	pop r16
	pop r16
	
	pop YH
	pop YL
	pop r16
	ret
	
set_initial_char:
	push XL
	push XH
	push r16
	push r17

	ldi XL, low(TIME_ARRAY)
	ldi XH, high(TIME_ARRAY)

	clr r17
set_char_loop:
	ldi r16, '0'
	st X+, r16
	inc r17
	cpi r17, 5
	brlo set_char_loop


	pop r17
	pop r16
	pop XH
	pop XL
	ret
	
set_initial_store:
	push XL
	push XH
	push r16
	push r17


	ldi XL, low(STORE_ARRAY1)
	ldi XH, high(STORE_ARRAY1)

	clr r17
set_char_loop1:
	ldi r16, '0'
	st X+, r16
	inc r17
	cpi r17, 5
	brlo set_char_loop1
	
	ldi XL, low(STORE_ARRAY2)
	ldi XH, high(STORE_ARRAY2)

	clr r17
set_char_loop2:
	ldi r16, '0'
	st X+, r16
	inc r17
	cpi r17, 5
	brlo set_char_loop2
	
	pop r17
	pop r16
	pop XH
	pop XL
	ret
	
	
	
increment_time:
	push r16
	push YL
	push YH
	push ZL
	push ZH
	push r17
	push r18
	
	

	ldi YL, low(TIME_ARRAY)
	ldi YH, high(TIME_ARRAY)
	
	ldi r17, 4  ; r17 = i
	
	;get A[4]
	add YL, r17
	clr r16
	adc YH, r16
	
	;A[4] += 1
	ld r16, Y
	inc r16
	st Y, r16
	
	
inc_loop:
	cpi r17, 1
	brlo inc_loop_end
	
	ldi YL, low(TIME_ARRAY)
	ldi YH, high(TIME_ARRAY)
	
	ldi ZL, low(MAXIMUM_VALUES_ARRAY<<1)
	ldi ZH, high(MAXIMUM_VALUES_ARRAY<<1)
	
	;get max[i]
	add ZL, r17
	clr r16
	adc ZH, r16
	lpm r18, Z
	
	;get A[i]
	add YL, r17
	clr r16
	adc YH, r16
	ld r16, Y
	
	dec r17 ;i-- 
	
	cp r18, r16
	brsh inc_loop
	;if A[i] > max[i]
	
	;A[i] = 0
	ldi r16,'0'
	st Y, r16
	
	;A[i-1] +=1
	ld r16, -Y
	inc r16
	st Y, r16
	
	rjmp inc_loop
	
inc_loop_end:

	ld r16, Y
	lpm r18, Z
	cp r18, r16
	brsh inc_end
	ldi r16, '0'
	st Y, r16

inc_end:
	pop r18
	pop r17
	pop ZH
	pop ZL
	pop YH
	pop YL
	pop r16
	ret	
	
	
	
MAXIMUM_VALUES_ARRAY:
	.db '9', '9', '5', '9', '9'
	
	
	
	
; Include LCD library code
.include "lcd_function_code.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.dseg
; Note that no .org 0x200 statement should be present
; Put variables and data arrays here...
	
LINE_ONE: .byte 100
LINE_TWO: .byte 100
TIME_ARRAY: .byte 5
STORE_ARRAY1: .byte 5
STORE_ARRAY2: .byte 5
OVERFLOW_INTERRUPT_COUNTER: .byte 1
stop_or_not: .byte 1