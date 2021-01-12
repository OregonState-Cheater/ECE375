;***********************************************************
;*
;*	Enter Name of file here
;*
;*	Enter the description of the program here
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Enter your name
;*	   Date: Enter Date
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register 
.def	temp = r17
.def	freezecount = r18
.def	waitcnt = r23
.def	ilcnt = r24
.def	olcnt = r25

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	Address = $1A		;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

.equ	MovFwdAct =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBckAct =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnRAct =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnLAct =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	HaltAct =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	FreezeAct =	 (0b11111000)							;0b11111000 Freeze Action Code
	
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:
;- Left whisker
.org	$0002					; Beginning of IVs
		rcall 	Hitright		; Reset interrupt
		reti
;- Right whisker
.org	$0004					; Beginning of IVs
		rcall 	Hitleft			; Reset interrupt
		reti
;-Timer interrupt
.org	$003A
		reti
		

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi		mpr, low(RAMEND)
	out		SPL, mpr
	ldi		mpr, high(RAMEND)
	out		SPH, mpr
	;I/O Ports
	ldi		mpr, $FF
	out		DDRB, mpr
	ldi		mpr, $00
	out		PORTB, mpr
	; Initialize I/O Ports
	ldi		mpr, $00
	out		DDRD, mpr
	ldi		mpr, $FF
	out		PORTD, mpr
	
	;External Interrupts
		; Initialize external interrupts
		ldi	mpr, 0b00001010			; Set the Interrupt Sense Control to falling edge 
		sts	EICRA, mpr
		; Set the Interrupt Sense Control to falling edge 
		ldi	mpr, 0b00000000
		out	EICRB, mpr
		;Set the External Interrupt Mask
		ldi	mpr, 0b00000011			; Set value to what we want to hide
		out	EIMSK, mpr

			; init the counter/timer3 normal, 256, interrupt enable
			; in this mode, the TOV3 flag is set when timer/counter3
			; overflows. it must be reset manually by writing a zero
			; to the ETIFR e.g. --> ldi   mpr, (0<<TOV3)
			;			sts   EITFR, mpr
			; Setting the TCNT3H,L registers to 3036 will reset the 
			; timer to the correct position before beginning the
			; count cycle again 

	; init the counter/timer3 normal, 256, interrupt enable
		ldi		mpr, high(3036)		; Set the starting value to 3036
		sts		TCNT3H, mpr
		ldi		mpr, low(3036)
		sts		TCNT3L, mpr

		ldi		mpr, 0	; Set normal mode
		sts		TCCR3A, mpr
		ldi		mpr, (1<<CS32)		; 256 prescaler
		sts		TCCR3B, mpr
		ldi		mpr, (1<<TOIE3)		; Enable the TOV interrupt
		sts		ETIMSK, mpr

/*
		ldi		mpr, high(31250)		; Set the starting value to 3036
		sts		OCR3AH, mpr
		ldi		mpr, low(31250)
		sts		OCR3AL, mpr

		ldi		mpr, (1<<COM3A1)|(1<<COM3A0)	; Set OC3A on overflow
		sts		TCCR3A, mpr
		ldi		mpr, (1<<WGM32)|(1<<CS32)		; 256 prescaler CTC Mode
		sts		TCCR3B, mpr
*/			
		;ldi		mpr, (1<<TOIE3)		; Enable the TOV interrupt
		;sts		ETIMSK, mpr
	;Other
	ldi		olcnt, $00
	ldi		freezecount, $00

	sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
TimeElapsed:
			;ldi		mpr, (0<<TOIE3)		; disable the TOV interrupt
			;sts		ETIMSK, mpr

			reti
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

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	$00
		out		PORTB,	mpr
		rcall	TimerWait
		
		; Preform left command wait 100 ms
		ldi		mpr,	$20 ; 0010 0000
		out		PORTB,	mpr
		rcall	TimerWait
		
		; Preform forward command
		ldi		mpr,	$60
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

		; Execute the function here
		; Preform reverse command wait 100 ms
		ldi		mpr,	0x0
		out		PORTB,	mpr
		rcall	TimerWait

		; Preform right command wait 100 ms
		ldi		mpr,	0x40
		out		PORTB,	mpr
		rcall	TimerWait

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

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
WaitFunc:
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

;----------------------------------------------------------------
; Sub:	TimerWait
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
TimerWait:	

	ldi		mpr, high(3036)		; Set the starting value to 3036
		sts		TCNT3H, mpr
		ldi		mpr, low(3036)
		sts		TCNT3L, mpr
		ldi		mpr, (1<<TOV3)
		;ldi		mpr, (1<<TOIE3)		; Enable the TOV interrupt
		;sts		ETIMSK, mpr
TIMERLOOP:
		lds		mpr, ETIFR
		sbrs	mpr, TOV3
		rjmp	TIMERLOOP
		ldi		mpr, (1<<TOV3)
		sts		ETIFR, mpr
		

		ret


;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************