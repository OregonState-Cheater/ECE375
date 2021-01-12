;***********************************************************
;*
;*	Aaron_Vaughan_and_Bradley_Heenk_Lab8_Tx_sourcecode.asm
;*
;*	Enter the description of the program here
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
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
.def	mpr = r16				; Multi-Purpose Register
.def	dataIO = r17			; Transmission data register
.def	waitcnt = r18			; Wait Loop Counter
.def	ilcnt = r19				; Inner Loop Counter
.def	olcnt = r20				; Outer Loop Counter

.equ	WTime = 50				; Time to wait in wait loop
.equ	Pause = 1				; Pause time
.equ	Address = $1A			; This is the Rx/Tx ID number
			
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	Freeze =  (0b11111000)							;freeze action code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

    ; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

	; Initialize Port D for input/output
		ldi		mpr, $0C		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input/output
		ldi		mpr, $F3		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State
	
		ldi		mpr, $F3
		out		PORTD, mpr
	; USART1
		; Set baudrate at 2400bps
		ldi		mpr, high(832)
		sts		UBRR1H, mpr
		ldi		mpr, low(832)
		sts		UBRR1L, mpr
		; Clear set 2x
		ldi		mpr, ((1<<U2X1))
		sts UCSR1A, mpr
		; Enable transmitter
		ldi		mpr, (1<<TXEN1)			; 0b01000000
		sts		UCSR1B, mpr
		; Set frame format: 8 data bits, 2 stop bits
		ldi		mpr, 0b00001110			; 0b00001110
		sts		UCSR1C, mpr

	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	; Start polling PORTB to check what we are supposed 
	; to be doing.
		in		mpr, PIND
		andi	mpr, 0b11110011		; Mask Tx/Rx pins
		
				
	; If button 0 is pressed send GoRight command
		sbrs	mpr, PIND0
		rcall	GoRight
	; If button 1 is pressed send GoLeft command
		sbrs	mpr, PIND1
		rcall	GoLeft
	; If button 4 is pressed send MovFwd command
		sbrs	mpr, PIND4
		rcall	GoFwd
	; If button 5 is pressed send MovBck command
		sbrs	mpr, PIND5
		rcall	GoBck
	; If button 6 is pressed send Stop command
		sbrs	mpr, PIND6
		rcall	Stop
	; If button 7 is pressed
		sbrs	mpr, PIND7
		rcall	Freeze_All

		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	USART_Transmit_instruction
; Desc:	This code uses polling of the UDRE flag to determine
;		when to send the data
;-----------------------------------------------------------
USART_Transmit:
		in		mpr, SREG		; Save program state
		push	mpr				;

			; Wait for the UDRE to be empty
		lds		mpr, UCSR1A		
		sbrs	mpr, UDRE1		
		rjmp	USART_Transmit	
			; Load dataIO into buffer and send it
		sts		UDR1, dataIO	
		
		pop		mpr				; Restore program state
		out		SREG, mpr		; 

		ret

;----------------------------------------------------------------
; Sub:	GoRight
; Desc:	Sends the GoRight command signal with address
;----------------------------------------------------------------
GoRight:
		push	mpr				; Save state of processor
		in		mpr, SREG		;
		push	mpr				;
		push	dataIO
		push	waitcnt
		
		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		
		ldi		dataIO, turnR	; Load Command
		rcall	USART_Transmit	; Transmit Command
				
		pop		waitcnt			; Restore state of processor
		pop		dataIO			; 
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr

		ret						; Return from subroutine

;----------------------------------------------------------------
; Sub:	GoLeft
; Desc:	Sends the GoLeft command signal with address
;----------------------------------------------------------------
GoLeft:
		push	mpr				; Save state of processor
		in		mpr, SREG		; 
		push	mpr				;
		push	dataIO
		push	waitcnt
		
		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait

		ldi		dataIO, TurnL	; Load Command
		rcall	USART_Transmit	; Transmit Command
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait
		
		pop		waitcnt			; Restore processor state
		pop		dataIO			;
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr

		ret						; Return from subroutine


;----------------------------------------------------------------
; Sub:	GoFwd
; Desc:	Sends the Gofwd command signal with address
;----------------------------------------------------------------
GoFwd:
		push	mpr				; Restore processor state
		in		mpr, SREG		; 
		push	mpr				;
		push	dataIO
		push	waitcnt			
		
		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait

		ldi		dataIO, MovFwd	; Load Command
		rcall	USART_Transmit	; Transmit Command
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait
		
		pop		waitcnt			; Restore processor state
		pop		dataIO			; 
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr				;

		ret						; Return from subroutine


;----------------------------------------------------------------
; Sub:	GoBck
; Desc:	Sends the GoBck command signal with address
;----------------------------------------------------------------
GoBck:
		push	mpr				; Save processor state
		in		mpr, SREG		; 
		push	mpr				;
		push	dataIO			;
		push	waitcnt			;
		
		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait

		ldi		dataIO, MovBck	; Load Command
		rcall	USART_Transmit	; Transmit Command
		ldi		waitcnt, Pause	; Pause for 10ms
		rcall	Wait
		
		pop		waitcnt			; Restore processor state
		pop		dataIO			;
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr

		ret						; Return from subroutine


;----------------------------------------------------------------
; Sub:	Stop
; Desc:	Sends the Stop command signal with address
;----------------------------------------------------------------
Stop:
		push	mpr				; Save processor state
		in		mpr, SREG		; 
		push	mpr				;
		push	dataIO
		push	waitcnt

		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		ldi		waitcnt, WTime	; Pause for 500ms
		rcall	Wait

		ldi		dataIO, Halt	; Load Command
		rcall	USART_Transmit	; Transmit Command
		ldi		waitcnt, Pause		; Pause for 500ms
		rcall	Wait
		
		pop		waitcnt			; Restore processor state
		pop		dataIO			;
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr

		ret						; Return from subroutine

;----------------------------------------------------------------
; Sub:	Freeze
; Desc:	Sends the Freeze signal
;----------------------------------------------------------------
Freeze_All:
		push	mpr				; Save processor state
		in		mpr, SREG		; 
		push	mpr				;
		push	dataIO
		push	waitcnt

		ldi		dataIO, Address	; Load Address
		rcall	USART_Transmit	; Transmit Address
		

		ldi		dataIO, Freeze	; Load Command
		rcall	USART_Transmit	; Transmit Command
		
		ldi		waitcnt, WTime	; 500ms wait period to prevent spamming of the freeze command
		rcall	Wait
		pop		waitcnt			; Restore processor state
		pop		dataIO			;
		pop		mpr				; 
		out		SREG, mpr		;
		pop		mpr

		ret						; Return from subroutine


;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
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