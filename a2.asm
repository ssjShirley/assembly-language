; a2_template.asm
; CSC 230 - Summer 2018

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                        Constants and Definitions                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Stack pointer and SREG registers (in data space)
.equ SPH_DS = 0x5E
.equ SPL_DS = 0x5D
.equ SREG_DS = 0x5F

; Initial address (16-bit) for the stack pointer
.equ STACK_INIT = 0x21FF

; Port and data direction register definitions (taken from AVR Studio; note that m2560def.inc does not give the data space address of PORTB)
.equ DDRB_DS = 0x24
.equ PORTB_DS = 0x25
.equ DDRL_DS = 0x10A
.equ PORTL_DS = 0x10B


; Definitions of the special register addresses for timer 0 (in data space)
.equ GTCCR_DS = 0x43
.equ OCR0A_DS = 0x47
.equ OCR0B_DS = 0x48
.equ TCCR0A_DS = 0x44
.equ TCCR0B_DS = 0x45
.equ TCNT0_DS  = 0x46
.equ TIFR0_DS  = 0x35
.equ TIMSK0_DS = 0x6E

; Definitions of the special register addresses for timer 2 (in data space)
.equ ASSR_DS = 0xB6
.equ OCR2A_DS = 0xB3
.equ OCR2B_DS = 0xB4
.equ TCCR2A_DS = 0xB0
.equ TCCR2B_DS = 0xB1
.equ TCNT2_DS  = 0xB2
.equ TIFR2_DS  = 0x37
.equ TIMSK2_DS = 0x70

; Definitions for the analog/digital converter (ADC)
.equ ADCSRA_DS	= 0x7A ; Control and Status Register A
.equ ADCSRB_DS	= 0x7B ; Control and Status Register B
.equ ADMUX_DS	= 0x7C ; Multiplexer Register
.equ ADCL_DS	= 0x78 ; Output register (high bits)
.equ ADCH_DS	= 0x79 ; Output register (low bits)

; v1.1
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352

; v1.0
.equ ADC_BTN_RIGHT = 0x032
.equ ADC_BTN_UP = 0x0C3
.equ ADC_BTN_DOWN = 0x17C
.equ ADC_BTN_LEFT = 0x22B
.equ ADC_BTN_SELECT = 0x316

.equ DELAY_ITERATIONS = 100000; 0.05second 2000000
.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp main_begin
	
; The interrupt vector for timer 2 overflow is 0x1e
.org 0x001e
	jmp TIMER2_OVERFLOW_ISR

; The interrupt vector for timer 0 overflow is 0x2e
.org 0x002e
	jmp TIMER0_OVERFLOW_ISR 
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; According to the datasheet, the last interrupt vector has address 0x0072, so the first
; "unreserved" location is 0x0074
.org 0x0074
main_begin:

	; Initialize the stack
	ldi r16, high(STACK_INIT)
	sts SPH_DS, r16
	ldi r16, low(STACK_INIT)
	sts SPL_DS, r16
	
	; Set DDRB and DDRL
	ldi r16, 0xff
	sts DDRL_DS, r16
	sts DDRB_DS, r16
	
	; Set up the ADC
	ldi	r16, 0x87
	sts	ADCSRA_DS, r16
	ldi	r16, 0x00
	sts	ADCSRB_DS, r16
	ldi	r16, 0x40
	sts	ADMUX_DS, r16
	
	;initialize current led and direction
	ldi r16, 0
	sts CURRENT_LED, r16
	ldi r16, 1
	sts DIRECTION, r16
	
	;initialize select button
	ldi r16, 0
	sts select_button_pressed, r16
	
	;initialize 1 second interrupt
	ldi r16, 244
	sts querter_second, r16

set_time0:
	call TIMER0_SETUP 
	sei 
	rjmp main_loop
	
set_time2:
	call TIMER2_SETUP 
	sei 
	rjmp main_loop
	
main_loop:

	lds	r16, ADCSRA_DS
	ori	r16, 0x40
	sts	ADCSRA_DS, r16

wait_for_adc:
	lds		r16, ADCSRA_DS
	andi	r16, 0x40
	brne	wait_for_adc
	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL_DS
	lds	XH, ADCH_DS
	
	call short_delay
	call button_pressed
	call set_index
	
	lds r16, index
	cpi r16, 1
	breq regular_mode
	cpi r16, 2
	breq delay_quarter_second
	cpi r16, 3
	breq delay_second
	cpi r16, 4
	breq inverted_mode
	cpi r16, 5
	breq select
	rjmp main_loop

; regular mode
regular_mode:
	rjmp set_time0

; 1/4 second
delay_quarter_second:
	ldi r17, 61
	sts querter_second, r17
	rjmp main_loop

; 1 second
delay_second:
	ldi r17, 244
	sts querter_second, r17
	rjmp main_loop

; inverted mode
inverted_mode:
	rjmp set_time2
	
;select button
select:
	lds r17, select_button_pressed
	cpi r17, 0
	breq set_select_pressed
	brne set_select_not
	
set_select_not:	
	ldi r17, 0
	sts select_button_pressed, r17
	rjmp main_loop
	
set_select_pressed:
	ldi r17, 1
	sts select_button_pressed, r17
	rjmp main_loop
	

;set the button index
set_index:
	push r20
	push r21
	push r16
	push r17
	push r18
	
	lds r17, last_valueL
	lds r18, last_valueH
	
	ldi	r20, low(ADC_BTN_RIGHT)
	ldi	r21, high(ADC_BTN_RIGHT)
	cp	r17, r20 ; Low byte
	cpc	r18, r21 ; High byte
	brlo set_right
	
	ldi	r20, low(ADC_BTN_UP)
	ldi	r21, high(ADC_BTN_UP)
	cp	r17, r20 ; Low byte
	cpc	r18, r21 ; High byte
	brlo set_up
	
	ldi	r20, low(ADC_BTN_DOWN)
	ldi	r21, high(ADC_BTN_DOWN)
	cp	r17, r20 ; Low byte
	cpc	r18, r21 ; High byte
	brlo set_down
	
	ldi	r20, low(ADC_BTN_LEFT)
	ldi	r21, high(ADC_BTN_LEFT)
	cp	r17, r20 ; Low byte
	cpc	r18, r21 ; High byte
	brlo set_left
	
	ldi	r20, low(ADC_BTN_SELECT)
	ldi	r21, high(ADC_BTN_SELECT)
	cp	r17, r20 ; Low byte
	cpc	r18, r21 ; High byte
	brlo set_select
	
	brsh set_no
	
set_right:
	ldi r16, 1
	sts index, r16
	rjmp set_button_end
set_up:
	ldi r16, 2
	sts index, r16
	rjmp set_button_end
set_down:
	ldi r16, 3
	sts index, r16
	rjmp set_button_end
set_left:
	ldi r16, 4
	sts index, r16
	rjmp set_button_end
set_select:
	ldi r16, 5
	sts index, r16
	rjmp set_button_end
set_no:
	ldi r16, 0
	sts index, r16
	rjmp set_button_end

set_button_end:
	pop r17
	pop r18
	pop r16
	pop r21
	pop r20
	ret
	
	
;read the ADC and return the last_value
button_pressed:
	push r16
	push r17
	push r18

	lds r16, button_count
	cpi r16, 0
	breq count_equal_zero
	brne count_not_zero

count_equal_zero:
	sts last_valueL, XL
	sts last_valueH, XH
	inc r16
	rjmp button_pressed_end

count_not_zero:
	lds r17, last_valueL
	lds r18, last_valueH
	cp  XL, r17
	cpc XH, r18
	breq last_value_equal
	brne last_value_notequal
	
last_value_equal:
	inc r16
	cpi r16, 5
	brne button_pressed_end

last_value_notequal:
	clr r16

button_pressed_end:
	sts button_count, r16
	
	pop r18
	pop r17
	pop r16
	ret
	
; End of main program

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

	
	
	
;time 0	
TIMER0_SETUP:
	push r16
	
	;remove time2
	ldi r16, 0x00
	sts TCCR2A_DS, r16
	sts TCCR2B_DS, r16
	sts TIMSK2_DS, r16
	sts TIFR2_DS, r16
	
	ldi r16, 0x00
	sts TCCR0A_DS, r16
	ldi r16, 0x04 
	sts	TCCR0B_DS, r16
	ldi r16, 0x01
	sts TIMSK0_DS, r16
	ldi r16, 0x01
	sts TIFR0_DS, r16
		
	pop r16
	ret

TIMER0_OVERFLOW_ISR:
	
	push r16
	lds r16, SREG_DS 
	push r16
	push r17
	push r18
	
	lds r16, OVERFLOW_INTERRUPT_COUNTER0
	
	lds r18, select_button_pressed
	cpi r18, 1
	breq no_add
	brne still_add
no_add: 
	ldi r17, 0
	rjmp select_end
still_add:	
	ldi r17, 1
	rjmp select_end
select_end:
	add r16, r17
	sts OVERFLOW_INTERRUPT_COUNTER0, r16

	lds r18, querter_second;
	cp r16, r18
	brlo timer0_isr_done

	sub r16, r18
	sts OVERFLOW_INTERRUPT_COUNTER0, r16

	;CURRENT_LED += DIRECTION
	lds r16, CURRENT_LED
	lds r17, DIRECTION
	add r16, r17
	sts CURRENT_LED, r16
	lds r16, CURRENT_LED
	;If we have reached LED 0, set the DIRECTION to be 1
	cpi r16, 0
	breq cur1
	;If we have reached LED 5, set the DIRECTION to be -1
	cpi r16, 5
	breq cur5
	rjmp wait
cur1:
	ldi r16, 1
	sts DIRECTION, r16
	rjmp wait
cur5:
	ldi r16, -1
	sts DIRECTION, r16
	rjmp wait

wait:		
	call clear_leds
	call set_leds
	
timer0_isr_done:
	pop r18
	pop r17
	pop r16 
	sts SREG_DS, r16 
	pop r16
	reti 

clear_leds:
	push r16
	
	clr r16
	sts PORTB_DS, r16
	sts PORTL_DS, r16
	
	pop r16
	ret

set_leds:
	push r16
	push ZL
	push ZH
	push r0
	
	clr r0
	ldi ZL, low(PATTERN_VALUE<<1)
	ldi ZH, high(PATTERN_VALUE<<1)
	
	lds r16, CURRENT_LED
	add ZL, r16
	adc ZH, r0
	lpm r0, Z
	cpi r16, 4
	brlo set_portL
	brsh set_portB
	
set_portL:	
	sts PORTL_DS, r0
	rjmp set_leds_end
	
set_portB:
	sts PORTB_DS, r0
	rjmp set_leds_end
	
set_leds_end:
	pop r0
	pop ZH
	pop ZL
	pop r16
	ret

PATTERN_VALUE:
	.db 0b10000000, 0b00100000, 0b00001000, 0b00000010, 0b00001000, 0b00000010
	
	

	
;	
;Time 2	
TIMER2_SETUP:
	push r16	
	
	;remove time0
	ldi r16, 0x00
	sts TCCR0A_DS, r16 
	sts	TCCR0B_DS, r16 
	sts TIMSK0_DS, r16
	sts TIFR0_DS, r16
	
	ldi r16, 0x00
	sts TCCR2A_DS, r16
	ldi r16, 0x06
	sts TCCR2B_DS, r16
	ldi r16, 0x01
	sts TIMSK2_DS, r16
	ldi r16, 0x01
	sts TIFR2_DS, r16
		
	pop r16
	ret

TIMER2_OVERFLOW_ISR:
	push r16
	lds r16, SREG_DS 
	push r16 
	push r17
	push r18
	
	lds r16, OVERFLOW_INTERRUPT_COUNTER0
	lds r17, select_button_pressed
	cpi r17, 1
	breq no_add2
	brne still_add2
no_add2: 
	ldi r17, 0
	rjmp select_end2
still_add2:	
	ldi r17, 1
	rjmp select_end2
select_end2:
	add r16, r17
	lds r18, querter_second 
	cp r16, r18  
	brne timer2_isr_done

	;CURRENT_LED += DIRECTION
	lds r16, CURRENT_LED
	lds r17, DIRECTION
	add r16, r17
	sts CURRENT_LED, r16
	lds r16, CURRENT_LED
	;If we have reached LED 0, set the DIRECTION to be 1
	cpi r16, 0
	breq cur12
	;If we have reached LED 5, set the DIRECTION to be -1
	cpi r16, 5
	breq cur52
	rjmp wait2
cur12:
	ldi r16, 1
	sts DIRECTION, r16
	rjmp wait2
cur52:
	ldi r16, -1
	sts DIRECTION, r16
	rjmp wait2
wait2:		
	call clear_leds2
	call set_leds2
	
	clr r16
	
timer2_isr_done:
	sts OVERFLOW_INTERRUPT_COUNTER0, r16
	
	pop r18
	pop r17
	pop r16
	sts SREG_DS, r16 
	pop r16
	reti 
	
clear_leds2:
	push r16 
	
	clr r16
	ldi r16, 0xff
	sts PORTB_DS, r16
	sts PORTL_DS, r16
	
	pop r16
	ret

set_leds2:
	push r16
	push ZL
	push ZH
	push r0
	
	clr r0
	ldi ZL, low(PATTERN_VALUES2<<1)
	ldi ZH, high(PATTERN_VALUES2<<1)
	lds r16, CURRENT_LED
	add ZL, r16
	adc ZH, r0
	lpm r0, Z
	cpi r16, 4
	brlo set_portL2
	brsh set_portB2
	
set_portL2:	
	sts PORTL_DS, r0
	rjmp set_leds_end2
	
set_portB2:
	sts PORTB_DS, r0
	rjmp set_leds_end2
	
set_leds_end2:
	pop r0
	pop ZH
	pop ZL
	pop r16
	ret

PATTERN_VALUES2:
	.db 0b01111111, 0b11011111, 0b11110111, 0b11111101, 0b11110111, 0b11111101
	

	




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.dseg
.org 0x200
; Add data memory variables here if needed...
last_valueL: .byte 1
last_valueH: .byte 1
button_count: .byte 1
CURRENT_LED: .byte 1
DIRECTION: .byte 1
index: .byte 1
OVERFLOW_INTERRUPT_COUNTER0: .byte 1
OVERFLOW_INTERRUPT_COUNTER2: .byte 1
querter_second: .byte 1
select_button_pressed: .byte 1