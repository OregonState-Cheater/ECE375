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
;- USART receive
.org	$003C					; Beginning of IVs
		rcall 	USART_Receive	; Reset interrupt
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
	;USART1
		;Set baudrate at 2400bps
		ldi		mpr, low(832)
		sts		UBRR1L, mpr
		ldi		mpr, high(832)
		sts		UBRR1H, mpr
		;Enable receiver and enable receive interrupts
		ldi		mpr, (1<<U2X1)
		sts		UCSR1A, mpr
		ldi		mpr, (1<<RXCIE1)|(1<<RXEN1)|(1<<TXEN1)
		sts		UCSR1B, mpr
		;Set frame format: 8 data bits, 2 stop bits
		ldi		mpr, (1<<UCSZ10)|(1<<UCSZ11)|(1<<USBS1)|(1<<UPM01)
		sts		UCSR1C, mpr
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

		;Set the Interrupt Sense Control to falling edge detection
		
	;Other
	ldi		olcnt, $00
	ldi		freezecount, $00

	sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		cpi		olcnt, $01
		brne	SHIT
		out		PORTB, temp
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
SHIT:	
		push	mpr
		ldi		olcnt, $01
		ldi		mpr, $60
		out		PORTB, mpr
		pop		mpr
		ret

;----------------------------------------------------------------
; Sub:	FILL IN
; Desc:	STUPID
;----------------------------------------------------------------
USART_Receive:
		; Save variable by pushing them to the stack
		push	mpr
		push	waitcnt
		in  	mpr, SREG
		push	mpr

		lds		mpr, UDR1
		cpi		mpr, Address
		breq	USART_OPCODE

		; Restore variable by popping them from the stack in reverse order
		pop 	mpr
		out 	SREG, mpr
		pop 	waitcnt
		pop 	mpr

		ret

;----------------------------------------------------------------
; Sub:	FILL IN
; Desc:	STUPID
;----------------------------------------------------------------
USART_OPCODE:
		
		lds		mpr, UDR1

		cpi		mpr, FreezeAct
		breq	FreezeFunc
		cpi		mpr, MovFwdAct
		breq	MovFwdFunc
		cpi		mpr, MovBckAct
		breq	MovBckFunc
		cpi		mpr, TurnRAct
		breq	TurnRFunc
		cpi		mpr, TurnLAct
		breq	TurnLFunc
		cpi		mpr, HaltAct
		breq	HaltFunc

		rjmp	OPCODEEXIT

FreezeFunc:
		ldi		mpr, Halt
		out		PORTB, mpr
		cpi		freezecount, 3
		breq	DIEINFIRE
		inc		freezecount
		rjmp	OPCODEEXIT

MovFwdFunc:
		ldi		mpr, MovFwd
		out		PORTB, mpr
		rjmp	OPCODEEXIT

MovBckFunc:
		ldi		mpr, MovBck
		out		PORTB, mpr		
		rjmp	OPCODEEXIT

TurnRFunc:
		ldi		mpr, TurnR
		out		PORTB, mpr	
		rjmp	OPCODEEXIT

TurnLFunc:
		ldi		mpr, TurnL
		out		PORTB, mpr		
		rjmp	OPCODEEXIT

HaltFunc:
		ldi		mpr, Halt
		out		PORTB, mpr		
		rjmp	OPCODEEXIT

DIEINFIRE:
		rjmp	DIEINFIRE

OPCODEEXIT:

		mov		temp, mpr
		rcall	USART_FLUSH

		ret

;----------------------------------------------------------------
; Sub:	FILL IN
; Desc:	STUPID
;----------------------------------------------------------------
USART_FLUSH:
		sbrs	mpr, RXC1
		ret

		lds		mpr, UDR1
		rjmp	USART_FLUSH

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
		ldi		waitcnt, 100
		rcall	WaitFunc

		; Preform left command wait 100 ms
		ldi		mpr,	$20 ; 0010 0000
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WaitFunc

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
		ldi		waitcnt, 100
		rcall	WaitFunc

		; Preform right command wait 100 ms
		ldi		mpr,	0x40
		out		PORTB,	mpr
		ldi		waitcnt, 100
		rcall	WaitFunc

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
;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************