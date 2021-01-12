;***********************************************************
;*
;*	Bradley_Heenk_and_Aaron_Vaughan_Lab6_sourcecode.asm
;*
;*	This program uses the process or interrupts intstead of
;*	polling for out BumpBots it also displays on the screen
;*	how many times each of the left or right whiskers are hit
;*	this displays up to a maximum of 19 which was how it was
;*	designed which is more than enough for this lab
;*
;*	This is the skeleton file for Lab 6 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Bradley Heenk and Aaron Vaughan
;*	   Date: 11/13/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register 
.def	waitcnt = r23
.def	ilcnt = r24
.def	olcnt = r25
.def	lastwsk = r2
.def	leftcnt = r3
.def	rightcnt = r4

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0002					; Beginning of IVs
		rcall 	HitRight		; Reset interrupt for HitLeft
		reti

.org	$0004
		rcall 	HitLeft			; Reset interrupt for HitRight
		reti

.org	$0006
		rcall 	HitRightClr		; Reset interrupt for HitLeftClr
		reti

.org	$0008
		rcall 	HitLeftClr		; Reset interrupt for HitRightClr
		reti

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:	; The initialization routine
		; Initialize Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr
		ldi		mpr, high(RAMEND)
		out		SPH, mpr

		; Initialize Port B for out output
		ldi		mpr, $00
		out		PORTB, mpr
		ldi		mpr, $FF
		out		DDRB, mpr

		; Initialize Port D for our inputs
		ldi		mpr, $FF
		out		PORTD, mpr
		ldi		mpr, $00
		out		DDRD, mpr

		; Initialize external interrupts
		ldi	mpr, 0b10101010			; Set the Interrupt Sense Control to falling edge 
		sts	EICRA, mpr
		
		ldi	mpr, 0b00000000			; Set the Interrupt Sense Control to falling edge 
		out	EICRB, mpr

		; Configure the External Interrupt Mask
		ldi	mpr, 0b00001111			; Set value to what we want to hide
		out	EIMSK, mpr

		rcall	LCDInit			; Initialize LCD Display
		ldi		mpr, $30
		mov		leftcnt, mpr
		mov		rightcnt, mpr

		; Get our screen intialized to zero to start with
		rcall	HitLeftClr
		rcall	HitRightClr

		; Turn on interrupts
		sei
			; NOTE: This must be the last thing to do in the INIT function

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program

		; Turn off the motors might remove...
		ldi	mpr,	0xF0		; Load 0xF0 into mpr to indicate stopped
		out	PORTB,	mpr			; Store mpr into the I/O register of PORTB

		; Move the bumpbot forward
		ldi	mpr,	0x60		; Load 0x60 into mpr to move forward
		out	PORTB,	mpr			; Store mpr into the I/O register of PORTB

		rjmp	MAIN			; Create an infinite while loop to signify the 
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:							; Begin a function with a label

		; Save variable by pushing them to the stack
		push	mpr
		push	waitcnt
		in  	mpr, SREG
		push	mpr

		; Setup our UpdateRight function for 0
		push	olcnt
		mov		olcnt, leftcnt
		rcall	UpdateLeft
		pop		olcnt

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	0x0
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WAITFUNC

		; Preform left command wait 100 ms
		ldi		mpr,	0x20
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WAITFUNC

		; Preform forward command
		ldi		mpr,	0x60
		out		PORTB,	mpr

		rcall	QueueFix
		ldi		mpr, $03
		out		EIFR, mpr

		; Restore variable by popping them from the stack in reverse order
		pop 	mpr
		out 	SREG, mpr
		pop 	waitcnt
		pop 	mpr

		ret						; End a function with RET

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:						; Begin a function with a label

		; Save variable by pushing them to the stack
		push	mpr	
		push	waitcnt
		in  	mpr, SREG
		push	mpr

		; Setup our UpdateRight function for 0
		push	ilcnt
		mov		ilcnt, rightcnt
		rcall	UpdateRight
		pop		ilcnt

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	0x0
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WAITFUNC

		; Preform right command wait 100 ms
		ldi		mpr,	0x40
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WAITFUNC

		; Preform forward command
		ldi		mpr,	0x60
		out		PORTB,	mpr

		rcall	QueueFix
		ldi		mpr, $03
		out		EIFR, mpr

		; Restore variable by popping them from the stack in reverse order
		pop 	mpr
		out 	SREG, mpr
		pop 	waitcnt
		pop 	mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Hit Right Function
; Desc: Prepares our update fucntion to be set to a "0"
;		then calls our fucntion to update the screen
;		this is used for when we want to clear a specific
;		button that is pressed
;-----------------------------------------------------------
HitRightClr:						; Begin a function with a label

		push	mpr				; Push registers onto the stack

		ldi		mpr, $30
		mov		rightcnt, mpr

		; Setup our UpdateLeft function
		push	ilcnt
		mov		ilcnt, rightcnt	; Load $30 ("0") into olcnt
		rcall	UpdateRight		; Call UpdateRight
		pop		ilcnt

		rcall	QueueFix		; Call the QueueFix function
		ldi		mpr, $03		; Load value of 3 into mpr
		out		EIFR, mpr		; Store to the I/O of EIFR with mpr

		pop		mpr				; Pop registers onto the stack

		ret						; End a function with RET		

;-----------------------------------------------------------
; Func: Hit Left Function
; Desc: Prepares our update fucntion to be set to a "0"
;		then calls our fucntion to update the screen
;		this is used for when we want to clear a specific
;		button that is pressed
;-----------------------------------------------------------
HitLeftClr:						; Begin a function with a label
		
		push	mpr				; Push registers onto the stack

		ldi		mpr, $30
		mov		leftcnt, mpr

		; Setup our UpdateLeft function
		push	olcnt
		mov		olcnt, leftcnt		; Load $30 ("0") into olcnt
		rcall	UpdateLeft		; Call UpdateLeft
		pop		olcnt

		rcall	QueueFix		; Call the QueueFix function
		ldi		mpr, $03		; Load value of 3 into mpr
		out		EIFR, mpr		; Store to the I/O of EIFR with mpr

		pop		mpr				; Pop registers off the stack

		ret						; End a function with RET	

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
WAITFUNC:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt			; Restore olcnt register
		pop		ilcnt			; Restore ilcnt register
		pop		waitcnt			; Restore wait register
		ret						; Return from subroutine

;-----------------------------------------------------------
; Func: Queue Fix Function
; Desc: This fucntions counts to around 600 micro seconds
;		this is used to help avoid queue delays since we
;		know our Atmega128 chip runs at 16 mhz we know each
;		clock cycle will be 1 / 16 mhz and convert it to
;		microseconds. Now we can take 600 value and divide
;		by out result which was used to determine how many
;		loops of 255 clock cycles we would need to stack
;		hence the inner loop and outer loops
;-----------------------------------------------------------
QueueFix:
		push	ilcnt			; Push registers onto the stack
		push	olcnt
		ldi		ilcnt, 255		; Load 255 into ilcnt
		ldi		olcnt, 30		; Load 30 into olcnt
ILOOPQUEUE:
		dec		ilcnt			; Decrement ilcnt
		brne	ILOOPQUEUE		; Branch if not equal to zero to ILOOPQUEUE
OLOOPQUEUE:
		ldi		ilcnt, 255		; Load 255 into ilcnt
		dec		olcnt			; Decrement olcnt
		brne	ILOOPQUEUE		; Branch if not equal to zero to ILOOPQUEUE

		pop		olcnt			; Pop registers off the stack
		pop		ilcnt
ret

;-----------------------------------------------------------
; Func: Update Left Function
; Desc: This uses the value in olcnt and loads that char
;		into the LCDscreen and updates that specific char
;-----------------------------------------------------------
UpdateLeft:						; Begin a function with a label

		push	mpr

		rcall	BaseText

		ldi		YL, low(LCDLn1Addr)		; Load the low byte of LCDLn1Addr into YL
		ldi		YH, high(LCDLn1Addr)	; Load the high byte of LCDLn1Addr into YH


		ldi		mpr, 4					; Load 14 into mpr this used for where on the screen we want to be
		add		YL, mpr					; Now add this value to YL

		mov		mpr, olcnt				; Copy and store olcnt into mpr
		cpi		mpr, $3A				; Compare mpr to $3A which is greater then 9			
		brge	TENSLEFT				; This indicated if were above 9 

		st		Y+, mpr					; Store mpr into Y
		
		ldi		mpr, $20				; Load $20 into mpr, $20 => " " character
		st		Y, mpr					; Store this value into Y

		rjmp	LEFTDONE				; End the fucntion by calling RIGHTDONE

TENSLEFT:
		ldi		mpr, $31				; Load a 1 into our MSB in our display
		st		Y+, mpr					; Store this value in our display

		mov		mpr, olcnt				; Copy and store olcnt into mpr
		subi	mpr, 10
		st		Y, mpr					; Store mpr into Y

LEFTDONE:

		rcall	LCDWrLn1				; Call the LCDWrite function to update the display

		inc		leftcnt

		pop		mpr

ret						; End a function with RET

;-----------------------------------------------------------
; Func: Update Right Function
; Desc: This uses the value in ilcnt and loads that char
;		into the LCDscreen and updates that specific char
;-----------------------------------------------------------
UpdateRight:						; Begin a function with a label

		push	mpr

		rcall	BaseText

		ldi		YL, low(LCDLn1Addr)		; Load the low byte of LCDLn1Addr into YL
		ldi		YH, high(LCDLn1Addr)	; Load the high byte of LCDLn1Addr into YH

		ldi		mpr, 14					; Load 14 into mpr this used for where on the screen we want to be
		add		YL, mpr					; Now add this value to YL

		mov		mpr, ilcnt				; Copy and store ilcnt into mpr
		cpi		mpr, $3A				; Compare mpr to $3A which is greater then 9			
		brge	TENSRIGHT				; This indicated if were above 9 

		st		Y+, mpr					; Store mpr into Y
		
		ldi		mpr, $20				; Load $20 into mpr, $20 => " " character
		st		Y, mpr					; Store this value into Y

		rjmp	RIGHTDONE				; End the fucntion by calling RIGHTDONE

TENSRIGHT:
		ldi		mpr, $31				; Load a 1 into our MSB in our display
		st		Y+, mpr					; Store this value in our display

		mov		mpr, ilcnt				; Copy and store ilcnt into mpr
		subi	mpr, 10
		st		Y, mpr					; Store mpr into Y

RIGHTDONE:

		rcall	LCDWrLn1				; Call the LCDWrite function to update the display

		inc		rightcnt				; Increment rightcnt

		pop		mpr

ret						; End a function with RET

;-----------------------------------------------------------
; Func: Base Text Function
; Desc: This uses the value in ilcnt and loads that char
;		into the LCDscreen and updates that specific char
;-----------------------------------------------------------
BaseText:						; Begin a function with a label

		push	mpr

		ldi		YL, low(LCDLn1Addr)		; Load the low byte of LCDLn1Addr into YL
		ldi		YH, high(LCDLn1Addr)	; Load the high byte of LCDLn1Addr into YH
		ldi		ZL, low(LW_BEG<<1)
		ldi		ZH, high(LW_BEG<<1)

		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc

		ldi		mpr, 6
		add		YL, mpr

		ldi		ZL, low(RW_BEG<<1)
		ldi		ZH, high(RW_BEG<<1)

		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc
		lpm		mpr, Z+					; Load program memory from where Z points into mpr
		st		Y+, mpr					; Store mpr into Y and post inc

		pop		mpr

ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

LW_BEG:
.DB		"LW: "		; Declaring data in ProgMem
LW_END:

RW_BEG:
.DB		"RW: "		; Declaring data in ProgMem
RW_END:

; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program
.include "LCDDriver.asm"				; Include the LCD Driver

