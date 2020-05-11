; divmod16.asm
; CSC 230 - Summer 2018
;
; Starter code for assignment 1
;
; B. Bird - 05/13/2018

.cseg
.org 0

	; Initialization code
	; Do not move or change these instructions or the registers they refer to. 
	; You may change the data values being loaded.
	; The default values set A = 0x3412 and B = 0x0003
	ldi r16, 0x12 ; Low byte of operand A
	ldi r17, 0x34 ; High byte of operand A
	ldi r18, 0x03 ; Low byte of operand B
	ldi r19, 0x00 ; High byte of operand B
	
	; Your task: Perform the integer division operation A/B and store the result in data memory. 
	; Store the 2 byte quotient in DIV1:DIV0 and store the 2 byte remainder in MOD1:MOD0.
	
	
	; ... Your code here ...
	

	ldi r21, 0 
	ldi r22, 0
	ldi r23, 1
	ldi r24, 0

	loop:
		cp r16, r18
		cpc r17, r19
		brlo store
		add r21, r23
		adc r22, r24
		sub r16, r18
		sbc r17, r19
		rjmp loop
		
store:
	sts DIV0, r21
	sts DIV1, r22
	sts MOD0, r16
	sts MOD1, r17
	
	; End of program (do not change the next two lines)
stop:
	rjmp stop
	
; Do not move or modify any code below this line. You may add extra variables if needed.
; The .dseg directive indicates that the following directives should apply to data memory
.dseg 
.org 0x200 ; Start assembling at address 0x200 of data memory (addresses less than 0x200 refer to registers and ports)

DIV0:	.byte 1 ; Bits  7...0 of the quotient
DIV1:	.byte 1 ; Bits 15...8 of the quotient
MOD0:	.byte 1 ; Bits  7...0 of the remainder
MOD1:	.byte 1 ; Bits 15...8 of the remainder
