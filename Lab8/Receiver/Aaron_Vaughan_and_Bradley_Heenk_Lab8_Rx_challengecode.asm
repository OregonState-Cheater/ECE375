;***********************************************************
;*
;*	Aaron_Vaughan_and_Bradley_Heenk_Lab8_Rx_challenegecode.asm
;*
;*	This program is the USART receiver which takes in
;*	various command from a transmitter and preforms 
;*	different functions based on what the transmitter sends.
;*	Also takes use of the old TurnLeft and TurnRight fucntions
;*	from previous labs. This is the extra credit challenge part
;*	which takes in the SpeedUp and SlowDown from Lab7
;*  which replaces the Halt and Freeze.
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Aaron Vaughan and Bradley Heenk
;*	   Date: 11/26/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register 
.def	check = r17
.def	freezecount = r18
.def	dataIO = r19
.def	rxcheck = r20
.def	memory = r21
.def	waitcnt = r23
.def	ilcnt = r24
.def	olcnt = r25

.equ	LongWait = 250

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
.equ	FreezeAll =	 (0b01010101)							;0b01010101 Freeze All Code
.equ	Step = $11						; Each Step is decimal 17
	
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
	ldi		mpr, 0b00001000
	out		DDRD, mpr
	ldi		mpr, 0b11110011
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

		ldi		mpr, 0	; Set normal mode
		sts		TCCR3A, mpr
		ldi		mpr, (1<<CS32)		; 256 prescaler
		sts		TCCR3B, mpr
		ldi		mpr, (1<<TOIE3)		; Enable the TOV interrupt
		sts		ETIMSK, mpr

	;Other
	ldi		memory, 0b01100000		; Setup our memory and setup for move forward
	out		PORTB, memory			; Set our LED's to move forward

	ldi		olcnt, 0		; Start at min speed
	ldi		ilcnt, 0		; Start at min speed
	ldi		check, 0				; Set our to zero
	ldi		freezecount, 0			; Set our freeze count to zero

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
; Sub:	USART Receive
; Desc:	Checks the first USART packet from UDR1 and calls two
;		different functions to either be fronzen from the
;		universal 
;----------------------------------------------------------------
USART_Receive:

		lds		mpr, UDR1

		; Check the address
		rjmp	USART_OPCODE			; Normal case check address and opcode

;----------------------------------------------------------------
; Sub:	Op Code
; Desc:	Gets called to check the address of the first USART
;		and calls the various other functions to reveice the
;		correct signal from the transmitter
;----------------------------------------------------------------
USART_OPCODE:
		
		sbrs	check, 0				; Checks lsb in check to see if its set and skip the next function
		rjmp	Address_Check			; If its not set go ahead and compare the address

		ldi		check, 0				; Setup check to zero since we know the next set of DATA

		cpi		mpr, FreezeAct			; Load action into mpr
		breq	FreezeFunc				; If true call FreezeFunc
		cpi		mpr, MovFwdAct			; Load action into mpr
		breq	MovFwdFunc				; If true call MovFwdFunc
		cpi		mpr, MovBckAct			; Load action into mpr
		breq	MovBckFunc				; If true call MovBckFunc
		cpi		mpr, TurnRAct			; Load action into mpr
		breq	TurnRFunc				; If true call TurnRFunc
		cpi		mpr, TurnLAct			; Load action into mpr 
		breq	TurnLFunc				; If true call TurnLFunc
		cpi		mpr, HaltAct			; Load action into mpr
		breq	HaltFunc				; If true call HaltFunc

		rjmp	OPCODEEXIT				; Exit if nothing compares

FreezeFunc:
		rcall	IncSpd	
		rjmp	OPCODEEXIT

MovFwdFunc:
		ldi		mpr, MovFwd				; Setup mpr with MovFwdFunc Command
		out		PORTB, mpr				; Load the command into PORTB
		rjmp	OPCODEEXIT

MovBckFunc:
		ldi		mpr, MovBck				; Setup mpr with MovBckFunc Command
		out		PORTB, mpr				; Load the command into PORTB		
		rjmp	OPCODEEXIT

TurnRFunc:
		ldi		mpr, TurnR				; Setup mpr with TurnRFunc Command
		out		PORTB, mpr				; Load the command into PORTB	
		rjmp	OPCODEEXIT

TurnLFunc:
		ldi		mpr, TurnL				; Setup mpr with TurnLFunc Command
		out		PORTB, mpr				; Load the command into PORTB		
		rjmp	OPCODEEXIT

HaltFunc:
		rcall	DecSpd		
		rjmp	OPCODEEXIT

Address_Check:
		cpi		mpr, Address			; Check to see if we are the correct address
		breq	Okay_Address			; If true setup setup our check register
		rjmp	OPCODEEXIT

Okay_Address:
		ldi		check, 1				; Load a one into check allow fucntion to bypass check next time
		rjmp	OPCODEEXIT

OPCODEEXIT:

		ret

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

		in		memory, PORTB			; Save old PORTB state

		; Execute the function here
		; Preform reverse command wait 100 ms
		in		ilcnt, PORTB	; Get the current state
		ldi		mpr,	0x0
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		or		ilcnt, mpr
		out		PORTB,	ilcnt
		rcall	TimerWait

		; Preform left command wait 100 ms
		in		ilcnt, PORTB	; Get the current state
		ldi		mpr,	0x20
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		or		ilcnt, mpr
		out		PORTB,	ilcnt
		rcall	TimerWait

		rcall	QueueFix
		ldi		mpr, $03
		out		EIFR, mpr

		out		PORTB, memory			; Restore old PORTB state

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

		in		memory, PORTB			; Save old PORTB state

		; Execute the function here
		; Preform reverse command wait 100 ms
		in		ilcnt, PORTB	; Get the current state
		ldi		mpr,	0x0
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		or		ilcnt, mpr
		out		PORTB,	ilcnt
		rcall	TimerWait

		; Preform right command wait 100 ms
		in		ilcnt, PORTB	; Get the current state
		ldi		mpr,	0x40
		andi	ilcnt, $0F	; Mask the motor state
		andi	mpr, $F0		; Mask the counter state
		or		ilcnt, mpr
		out		PORTB,	ilcnt
		rcall	TimerWait

		rcall	QueueFix
		ldi		mpr, $03
		out		EIFR, mpr

		out		PORTB, memory			; Restore old PORTB state

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

;***********************************************************
;*	Additional Program Includes
;***********************************************************