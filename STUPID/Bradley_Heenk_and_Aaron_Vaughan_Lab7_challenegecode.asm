;***********************************************************
;*
;*	Aaron_Vaughan_and_Brandley_Heenk_Lab7_challengecode.avr
;*
;*	This program uses fast PWM 8-bit timers
;*  to simulate a motor controller. The speed
;*  is displayed via a binary counter
;*
;*	This is the skeleton file for Lab 7 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Aaron Vaughan and Bradley Heenk
;*	   Date: 11/15/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
	; Registers R17 to R22 are
	; reserved for the LCD driver
.def	waitcnt = r23
.def	ilcnt = r24				; Also the speed counter
.def	olcnt = r25				; Also the step register
.def	counter = r5


.equ	EngEnR = 4				; right Engine Enable Bit
.equ	EngEnL = 7				; left Engine Enable Bit
.equ	EngDirR = 5				; right Engine Direction Bit
.equ	EngDirL = 6				; left Engine Direction Bit

.equ	Normal_Mode = 0

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00				; Move Backward Command
.equ	TurnR = (1<<EngDirL)			; Turn Right Command
.equ	TurnL = (1<<EngDirR)			; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command
.equ	Step = $11						; Each Step is decimal 17
.equ	One = $31
.equ	Zero = $30

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org	$0002
		rcall MaxSpd			; call max speed handler
		reti
.org	$0004
		rcall MinSpd			; call min speed handler
		reti
.org	$0006
		rcall IncSpd			; call inc speed handler
		reti
.org	$0008
		rcall DecSpd			; call dec speed handler
		reti
.org	$003A
		rcall TimeElapsed
		reti
.org	$0046					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

		; Configure I/O ports
		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		mov		counter, mpr
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State
		
		; Initialize external interrupts
		ldi	mpr, $AA			; Set the Interrupt Sense Control to falling edge 
		sts	EICRA, mpr
		
		; Configure the External Interrupt Mask
		ldi	mpr, $0F			; Set value to what we want to hide
		out	EIMSK, mpr

		; Configure 8-bit Timer/Counters
		ldi		mpr, $79		; No prescaling, Fast PWM, Inverted Compare
		out		TCCR0, mpr
		ldi		mpr, $79		; No prescaling, Fast PWM, Inverted Compare
		out		TCCR2, mpr

			; init the counter/timer3 normal, 256, interrupt enable
		ldi		mpr, high(3036)		; Set the starting value to 3036
		sts		TCNT3H, mpr
		ldi		mpr, low(3036)
		sts		TCNT3L, mpr

		ldi		mpr, Normal_Mode	; Set normal mode
		sts		TCCR3A, mpr
		ldi		mpr, (1<<CS32)		; 256 prescaler
		sts		TCCR3B, mpr
		ldi		mpr, (1<<TOIE3)		; Enable the TOV interrupt
		sts		ETIMSK, mpr



		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL)
		; Initialize TekBot Forward Movement
		ldi		mpr, MovFwd		; Load Move Forward Command
		out		PORTB, mpr		; Send command to motors


		; Set initial speed, display on Port B pins 3:0
		ldi		olcnt, $00		; Start at min speed
		ldi		ilcnt, $00		; Start at min speed
		or		mpr, ilcnt
		out		PORTB, mpr

		rcall	LCDInit

		; Enable global interrupts (if any are used)
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
			; Wait for an interrupt and just loop around
		
		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	Time Elapsed
; Desc:	When executed resets the LCD driver to start
;		counting in binary from 0 to 11111111 where each
;		time it gets incremented it is based on 
;-----------------------------------------------------------
TimeElapsed:
		; Save the states of the registers and push onto the stack
		push	waitcnt
		push	mpr
		push	ilcnt
		in		mpr, SREG			; Save the state of SREG
		push	mpr
		push	olcnt

		mov		mpr, counter
		rcall	LCDBinary

		inc		mpr
		mov		counter, mpr

		; Restore the old values to our registers and remove off the stack
		pop		olcnt
		pop		mpr
		out		SREG, mpr			; Restore the state of SREG
		pop		ilcnt
		pop		mpr
		pop		waitcnt

		ret
		
;-----------------------------------------------------------
; Func:	LCD Binary
; Desc:	An Extension of the LCDDrive.asm library to take
;		a specific value in mpr and display its on the lcd
;		in binary output with no leading zeroes and update
;		the display
;-----------------------------------------------------------
LCDBinary:

		ldi		XL, low(LCDLn1Addr)		; Load the low byte of LCDLn1Addr into XL
		ldi		XH, high(LCDLn1Addr)	; Load the high byte of LCDLn1Addr into XH

		ldi		waitcnt, 0				; Changes to a 1 when we detect our first 1
		rcall	LCDClr					; Clear the display

		sbrc	mpr, 7					; Check if the 7th bit has leading zero if 
										; If so then skip the next instruction
		ldi		waitcnt, 1				; If executed we hit our first one enable writing
		sbrs	mpr, 7					; Check the 7th bit if set skip the next instruction
		rcall	DisplayZero				; Since we were cleared go ahead and display a one
		sbrc    mpr, 7					; Check the 7th bit if cleared skip the next instruction
		rcall	DisplayOne				; Since we were set go ahead and display a one
		
		; Same sort of setup for the rest of these...
		; Except for the last step which will always display
		; The leading zero

		sbrc	mpr, 6
		ldi		waitcnt, 1
		sbrs	mpr, 6
		rcall	DisplayZero
		sbrc    mpr, 6
		rcall	DisplayOne

		sbrc	mpr, 5
		ldi		waitcnt, 1
		sbrs	mpr, 5
		rcall	DisplayZero
		sbrc    mpr, 5
		rcall	DisplayOne

		sbrc	mpr, 4
		ldi		waitcnt, 1
		sbrs	mpr, 4
		rcall	DisplayZero
		sbrc    mpr, 4
		rcall	DisplayOne

		sbrc	mpr, 3
		ldi		waitcnt, 1
		sbrs	mpr, 3
		rcall	DisplayZero
		sbrc    mpr, 3
		rcall	DisplayOne

		sbrc	mpr, 2
		ldi		waitcnt, 1
		sbrs	mpr, 2
		rcall	DisplayZero
		sbrc    mpr, 2
		rcall	DisplayOne

		sbrc	mpr, 1
		ldi		waitcnt, 1
		sbrs	mpr, 1
		rcall	DisplayZero
		sbrc    mpr, 1
		rcall	DisplayOne

		ldi		waitcnt, 1
		sbrs	mpr, 0
		rcall	DisplayZero
		sbrc    mpr, 0
		rcall	DisplayOne

		rcall	LCDWrite

		ret

;-----------------------------------------------------------
; Func:	Display Zero
; Desc:	Loads a Zero into the display and post-inc's X
;-----------------------------------------------------------
DisplayZero:
		
		cpi		waitcnt,1			; Check if we can start writing Zeroes
		brne	DISPZEROEXIT		; If not then exit 

		ldi		ilcnt, Zero			; Load our Zero value into a register ilcnt
		st		X+, ilcnt			; Load the value in ilcnt into the display
									; and post inc X

DISPZEROEXIT:

		ret

;-----------------------------------------------------------
; Func:	Display One
; Desc:	Loads a One into the display and post-inc's X
;-----------------------------------------------------------
DisplayOne:
		ldi		ilcnt, One			; Load a one into ilcnt register
		st		X+, ilcnt			; Load the value in ilcnt into our display
									; then post in X so we point to the next spot

DISPONEEXIT:

		ret

;-----------------------------------------------------------
; Func:	Max Speed
; Desc:	Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
MaxSpd:	; Begin a function with a label

		; If needed, save variables by pushing to the stack
		push	mpr
		push	ilcnt

		in		mpr, portB
		andi	mpr, $0F
		cpi		mpr, $0F
		breq	START
		clr		counter

START:
		; Execute the function here
		ldi		mpr, $ff
		out		OCR0, mpr
		out		OCR2, mpr
		ldi		mpr, 0b01101111	; Force motors to max speed
		out		PORTB, mpr		; Send command to motors
		
		; Restore any saved variables by popping from stack
		pop		ilcnt
		pop		mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	Min Speed
; Desc:	Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
MinSpd:	; Begin a function with a label

		; If needed, save variables by pushing to the stack
		push	mpr
		; Execute the function here

		in		mpr, portB
		andi	mpr, $0F
		cpi		mpr, $00
		breq	START1
		clr		counter

START1:
		ldi		ilcnt, $00
		push	ilcnt
		ldi		mpr, $00
		out		OCR0, mpr
		out		OCR2, mpr
		ldi		mpr, 0b11110000	; Force motors to min speed
		out		PORTB, mpr		; Send command to motors
		
		; Restore any saved variables by popping from stack
		pop		ilcnt
		pop		mpr
		
		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	Increment Speed
; Desc:	This funciton should increment the binary output
;		on PORTB(0..3) and increment OCCR0 by "step"
;-----------------------------------------------------------
IncSpd:	; Begin a function with a label
	
		; If needed, save variables by pushing to the stack
		push	mpr
		push	ilcnt
		in		mpr, SREG
		push	mpr
		push	olcnt

		; Execute the function here
		
		in		ilcnt, PORTB	; Get the current state
		mov		mpr, ilcnt	; Get a copy of current state
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		cpi		ilcnt, $0F	; Make sure we arent at max speed
		breq	SKIP_ADD		; Skip the update if we are

			; Step the motor speed by 1/16 speed increments
		clr		counter
		push	mpr				; Save mpr
		ldi		mpr, step		; Load in the step value (decimal 17)
		in		olcnt, OCR0	; Get the current speed
		add		olcnt, mpr	; Increment the speed by the step value
		out		OCR0, olcnt	; Set the new speed
		out		OCR2, olcnt	; Set the new speed
		pop		mpr
			; Increment the speed display
		inc		ilcnt		; Increment the Speed counter to update the led count
		or		ilcnt, mpr
		out		PORTB, ilcnt	; Update the LEDs

SKIP_ADD:	
			; This is for Debounce sequence, wait and flag...
		rcall	WAITFUNC
		ldi		mpr, $0F	
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		olcnt
		pop		mpr
		out		SREG, mpr
		pop		ilcnt
		pop		mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Decrement Speed
; Desc:	Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
DecSpd:	; Begin a function with a label

		; If needed, save variables by pushing to the stack
		push	mpr
		push	ilcnt
		in		mpr, SREG
		push	mpr
		push	olcnt

		; Execute the function here
		
		in		ilcnt, PORTB	; Get the current Speed count
		mov		mpr, ilcnt	; Get a copy of the current state of the output
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		cpi		ilcnt, $00	; Make sure we aren't at min speed already
		breq	SKIP_ADD2		; Skip the rest if we are	
		
			; Step the motor speed by 1/16 speed increments
		clr		counter
		push	mpr				; Save mpr
		ldi		mpr, step		; Load in the step value (decimal 17)
		in		olcnt, OCR0	; Get the current speed
		sub		olcnt, mpr	; decrement the speed by the step value
		out		OCR0, olcnt	; Set the new speed
		out		OCR2, olcnt	; Set the new speed
		pop		mpr
			; Decrement the speed count display
		dec		ilcnt		; Increment the Speed counter to update the led count
		or		ilcnt, mpr	; Get the new state of our motors and count
		out		PORTB, ilcnt	; Update the LEDs to display new state

SKIP_ADD2:
			; This is our debounce sequence, wait and flag...		
		rcall	WAITFUNC	
		ldi		mpr, $0F	
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		olcnt
		pop		mpr
		out		SREG, mpr
		pop		ilcnt
		pop		mpr

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
OLoop:	ldi		ilcnt, 30		; load ilcnt register
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

;***********************************************************
;*	Stored Program Data
;***********************************************************
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		.include "LCDDriver.asm"
