;***********************************************************
;*
;*	Bradley_Heenk_and_Aaron_Vaughan_Lab6_challenegecode.asm
;*
;*	This program uses the process or interrupts intstead of
;*	polling for out BumpBots it also displays on the screen
;*	how many times each of the left or right whiskers are hit
;*	this displays up to a maximum of 19 which was how it was
;*	designed which is more than enough for this lab. This
;*	program also detects when we're int a corner or hit
;*	the same whisker twice.
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
.def	memory = r5
.def	lastwsk = r2
.def	leftcnt = r3
.def	rightcnt = r4
.def	currentwsk = r6
.def	checkbit = r7

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

		; Turns off the motors 
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

		ldi		mpr, $01			; Load 1 into mpr
		mov		currentwsk, mpr		; Load mpr into the current whisker

		; Setup our UpdateRight function for 0
		push	olcnt
		mov		olcnt, leftcnt		; Move our current left whisker counter to olcnt
		rcall	UpdateLeft			; Call our update counter function
		pop		olcnt

		rcall	CornerCase			; Call the cornercase function to check if we are stuck
		sbrs	checkbit,0			; Check if the checkbit is set and if so skip rjmp LEFTSKIP
		rjmp	LEFTSKIP			; Relative jump to LEFTSKIP

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

LEFTSKIP:

		rcall	QueueFix			; Call the QueueFix function for 600 us delay
		ldi		mpr, $03			; Load $03 into mpr and have a 
		out		EIFR, mpr

		ldi		mpr, $01			; Load $01 into mpr
		mov		lastwsk, mpr		; Load mpr into the lastwsk

		ldi		mpr, $01			; Load $01 into mpr
		mov		checkbit, mpr		; Load mpr into the checkbit

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

		ldi		mpr, $02
		mov		currentwsk, mpr

		; Setup our UpdateRight function for 0
		push	ilcnt
		mov		ilcnt, rightcnt
		rcall	UpdateRight			; Call the update right function 
		pop		ilcnt

		rcall	CornerCase			; Call our corner case function
		sbrs	checkbit,0			; Skip the next step if the bit if checkbit is set
		rjmp	RIGHTSKIP			; Jump to RIGTHSKIP

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

RIGHTSKIP:

		rcall	QueueFix			; Call the queue function for 600 us delay
		ldi		mpr, $03			; Store $03 into mpr
		out		EIFR, mpr			; Load mpr into the I/O of EIFR

		ldi		mpr, $02			; $02 into mpr
		mov		lastwsk, mpr		; Load mpr nto lastwsk
			
		ldi		mpr, $01			; Load $01 into mpr
		mov		checkbit, mpr		; Load 1 into checkbit

		; Restore variable by popping them from the stack in reverse order
		pop 	mpr
		out 	SREG, mpr
		pop 	waitcnt
		pop 	mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Hit Right Clear Function
; Desc: Prepares our update fucntion to be set to a "0"
;		then calls our fucntion to update the screen
;		this is used for when we want to clear a specific
;		button that is pressed
;-----------------------------------------------------------
HitRightClr:						; Begin a function with a label

		push	mpr				; Push registers onto the stack

		ldi		mpr, $30				; Load the value of $30 into mpr
		mov		rightcnt, mpr			; Load mpr into rightcnt
		ldi		mpr, $00				; Load 0 into mpr
		mov		lastwsk, mpr			; Set the last wsk to 0
		mov		currentwsk, mpr			; Set the current wsk to 0
		mov		memory, mpr				; Set the memory to 0

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
; Func: Hit Clear Left
; Desc: Prepares our update fucntion to be set to a "0"
;		then calls our fucntion to update the screen
;		this is used for when we want to clear a specific
;		button that is pressed
;-----------------------------------------------------------
HitLeftClr:						; Begin a function with a label
		
		push	mpr				; Push registers onto the stack

		ldi		mpr, $30				; Load the value $30 into mpr
		mov		leftcnt, mpr			; Load leftcnt with mpr
		ldi		mpr, $00				; Load the value of 0 into mpr
		mov		lastwsk, mpr			; Set the last wsk to 0
		mov		currentwsk, mpr			; Set the current wsk to 0
		mov		memory, mpr				; Set the memory to 0

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
		ldi		olcnt, 1		; Load 30 into olcnt
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

;----------------------------------------------------------------
; Sub:	Corner Case
; Desc:	This function checks alternating left and right whisker
;		pushes on our board if it alternates left then right for
;		a total of 5 times it will turn 180 degrees and move
;		forward instaed
;----------------------------------------------------------------
CornerCase:

		push	mpr

		mov		mpr, lastwsk		; Move laskwsk into mpr

		cpi		mpr, 0				; Compare mpr to 0
		breq	CORNEREXIT			; If true brance to CORNEREXIT
		mov		mpr, currentwsk		; move currentwsk into mpr
		cpi		mpr, 1				; Compare mpr to 1
		breq	LEFTWHISKER			; If true branch to LEFTWHISKER
		cpi		mpr, 2				; Compare mpr to 2
		breq	RIGHTWHISKER		; If true branch to RIGHTWHISKER
		rjmp	CORNEREXIT			; Sanity check in case mpr is garbage


LEFTWHISKER:	; If left whisker is hit this is executed
		cp		currentwsk, lastwsk ; Compare current whisker to last hisker
		breq	SAME				; If true we hit the same whisker and branch to SAME
		
		mov		mpr, memory			; Load our memory for our cases into mpr
		andi	mpr, $F0			; And the 4 most significant bits and store into mpr

		cpi		mpr, 0b01000000		; Check if the left most bits = 4
		breq	STUCK				; If true execute our STUCK corner case function

		push	olcnt				; Push olcnt onto the stack
		ldi		olcnt, $10			; Load $01 into olcnt
		add		mpr, olcnt			; add olcnt to mpr and store into mpr
		
		mov		olcnt, memory		; Move our memory into olcnt
		andi	olcnt, $0F			; And olcnt with 0F getting us the right most significant bits
		add		mpr, olcnt			; Add olcnt with mpr and store intro
		pop		olcnt 				; Pop olcnt off the stack

		mov		memory, mpr			; move mpr into memory and replace it

		rjmp	CORNEREXIT			; Go to the end of our function

RIGHTWHISKER:	; If right whisker is hit this is executed
		cp		currentwsk, lastwsk ; Compare last whisker to current whisker
		breq	SAME				; If true branch to the same meaning the same whisker is hit

		mov		mpr, memory			; Load our memory into mpr
		andi	mpr, $0F			; And the 4 least significant bits and store into mpr

		cpi		mpr, 0b00000100		; Compare the least signicant 4 bits
		breq	STUCK				; if true branch to STUCK statement

		push	olcnt				; Push olcnt onto the stack
		ldi		olcnt, $01			; Load $01 into olcnt
		add		mpr, olcnt			; Add mpr with olcnt and store into mpr
		
		mov		olcnt, memory		; Move our memory into olcnt
		andi	olcnt, $F0			; And the 4 most signficant bits and store into olcnt
		add		mpr, olcnt			; Add olcnt with mpr and store into mpr
		pop		olcnt 				; Pop olcnt off the stack

		mov		memory, mpr			; Move our new mpr value into memory

		rjmp	CORNEREXIT		; Go to the end of our function

SAME:
		rcall	SameWhisker			; We ended up in this area call SameWhisker
		rjmp	CORNEREXIT			; Jump to the end of our function

STUCK:
		rcall	ImStuck				; We ended up in this area call ImStuck
		rjmp	CORNEREXIT			; Jump to the end of our function

CORNEREXIT:
		
		pop		mpr					; Pop mpr off the stack

		ret						; Return from subroutine

;-----------------------------------------------------------
; Func: Im Stuck
; Desc: This function preforms the flip and turn 180 degrees
;		to turn around and get unstuck from the corner
;-----------------------------------------------------------
ImStuck:
		ldi		mpr, $00		; Load $00 into mpr
		mov		memory, mpr		; Move mpr into memory to reset our memory

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	0x0
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WAITFUNC

		; Preform right command wait 100 ms
		ldi		mpr,	0x40
		out		PORTB,	mpr

		; Wait for 4 seconds
		ldi		waitcnt, 200
		rcall	WAITFUNC
		ldi		waitcnt, 200
		rcall	WAITFUNC

		; Preform forward command
		ldi		mpr,	0x60
		out		PORTB,	mpr

		ldi		mpr, $00		; Load $00 into mpr
		mov		checkbit, mpr	; Move mpr into the checkbit

		ret

;-----------------------------------------------------------
; Func: Same Whisker
; Desc: This fucntion calls the same whisker fucntion
;		when the same whisker is hit to avoid hitting
;		the same object over and over again.
;-----------------------------------------------------------
SameWhisker:
		ldi		mpr, $00		; Load $00 into mpr
		mov		memory, mpr		; Move mpr into memory to reset our memory

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	0x0
		out		PORTB,	mpr
		ldi		waitcnt, 200
		rcall	WAITFUNC

		; Preform right command wait 100 ms
		ldi		mpr,	0x40
		out		PORTB,	mpr

		; Wait for 2 seconds
		ldi		waitcnt, 200
		rcall	WAITFUNC
		dec		ilcnt

		; Preform forward command
		ldi		mpr,	0x60
		out		PORTB,	mpr

		ldi		mpr, $00		; Load $00 into mpr
		mov		checkbit, mpr	; Move mpr into the checkbit

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

