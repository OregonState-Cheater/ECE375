

;***********************************************************
;*
;*	Aaaron_Vaughan_and_Bradley_Heenk_Lab4_sourcecode.asm
;*
;*	This program uses AVR to display strings on the LCD screen
;*	S8 clears the screen, S1 Displays Bradley Heenk line one and
;*	Aarron Vaughan line 2. The S2 switch flips the order.
;*
;*	This is the skeleton file for Lab 4 of ECE 375
;*
;***********************************************************
;*
;*	Author: Bradley Heenk and Aarron Vaughan
;*	Date: 10/30/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is
								; required for LCD Driver
.def	countin = r23			; Counter value for loops'
.def	countout = r24			; Counter value for loops

.equ	forward = 0b11111110	; Setting up the S0
.equ	reverse	= 0b11111101	; Setting up the S1
.equ	erase = 0b01111111		; Setting up the S7

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
 		rjmp INIT				; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:								; The initialization routine

		ldi mpr, low(RAMEND) ; initialize Stack Pointer
		out SPL, mpr
		ldi mpr, high(RAMEND)
		out SPH, mpr

		out		DDRD, mpr		; Set Port D Data Direction Register
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		ldi		mpr, $00		; Empyting mpr with zeroes
		ldi		countin, $00	; Empyting countin with zeroes
		ldi		countout, $00	; Empyting countout with zeroes

		rcall	LCDInit			; Initialize LCD Display

		; NOTE that there is no RET or RJMP from INIT, this
		; is because the next instruction executed is the
		; first instruction of the main program

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in		mpr, PIND		; Setup PIND for input
		cpi		mpr, forward	; Compare our first pin to mpr
		brne	CASE1			; If not check the next case
		rcall	S1_DISPLAY		; If equal we call S1_DISPLAY
		rjmp	MAIN			; Start over jump to MAIN
CASE1:	
		cpi		mpr, reverse	; Compare reverse pin to mpr
		brne	CASE2			; If not check next case
		rcall	S2_DISPLAY		; If equal we call S2_DISPLAY
		rjmp	MAIN			; Start over jump to MAIN
CASE2:  
		cpi		mpr, erase		; Compare erase pin to mpr
		brne	MAIN			; If not jump to MAIN
		rcall	S8_CLEAR		; If equal we call S8_CLEAR
		rjmp	MAIN			; Start over jump to MAIN


;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	S1 Display
; Desc:	A micro-function for PARTNER_WRITE to simplify
; what is said in main. This fucntion sets everything up
; to display partner 1 on line 1 and partner 2 on line 2
;----------------------------------------------------------------
S1_DISPLAY:
		push	countin			; Pushes countin onto the stack
		push	countout		; Pushes countout onto the stack
		push	mpr				; Pushes mpr onto the stack

		ldi		countin, $02	; Declare partner 1 to prep our fucntion
		ldi		countout, $02	; Declare line 1 to prep our fucntion
		rcall	PARTNER_WRITE	; Calls PARTNER_WRITE with setup parameters

		ldi		countin, $01	; Declare partner 2 to prep our fucntion
		ldi		countout, $01	; Declare line 2 to prep our fucntion
		rcall	PARTNER_WRITE	; Calls PARTNER_WRITE with setup parameters

		pop		mpr				; Pops countin off the stack
		pop		countout		; Pops countout off the stack
		pop		countin			; Pops mpr off the stack
ret

;----------------------------------------------------------------
; Sub:	S2 Display
; Desc:	A micro-function for PARTNER_WRITE to simplify
; what is said in main. This fucntion sets everything up
; to display partner 2 on line 1 and partner 1 on line 2
;----------------------------------------------------------------
S2_DISPLAY:
		push	countin			; Pushes countin onto the stack
		push	countout		; Pushes countout onto the stack
		push	mpr				; Pushes mpr onto the stack

		ldi		countin, $01	; Declare partner 1 to prep our fucntion
		ldi		countout, $02	; Declare line 2 to prep our fucntion
		rcall	PARTNER_WRITE	; Calls PARTNER_WRITE with setup parameters

		ldi		countin, $02	; Declar partner 2 to prep our fucntion
		ldi		countout, $01	; Declare line 1 to prep our fucntion
		rcall	PARTNER_WRITE	; Calls PARTNER_WRITE with setup parameters

		pop		mpr				; Pops countin off the stack
		pop		countout		; Pops countout off the stack
		pop		countin			; Pops mpr off the stack
ret

;-----------------------------------------------------------
; Func: S8 Clear
; Desc: This fucntion clears the LCD Screen by calling the
; LCDClr in the LCDDriver.asm
;-----------------------------------------------------------
S8_CLEAR:
	rcall	LCDClr				; Calls the LCDClear function to clear display	
ret

;----------------------------------------------------------------
; Sub:	Writes partner based on the line types
; Desc:	This fucntion depends on countin being set
; before being called to either 1 or a 2 to indicate which 
; partner. The is true with count out which corlates to which
; line mpr is set to; 1 means line 1, 2 means line 2.
;----------------------------------------------------------------

PARTNER_WRITE:
		cpi		countin, $01				; Checks if we're partner 1
		breq	PARTNER1					; If true branches to the right Partner1
		cpi		countin, $02				; Checks if we're partner 2
		breq	PARTNER2					; If true branches to the right Partner2
		rjmp	PARTNER_EXIT				; Countin wasn't setup correctly jump to PARTNER_EXIT
PARTNER1:
		ldi		ZL, low(PARTNER1_BEG<<1)	; Load left-shited PARTNER1_BEG low byte into ZL
		ldi		ZH, high(PARTNER1_BEG<<1)	; Load left-shited PARTNER1_BEG high byte into ZH
		rjmp	CHECKLINES					; Jump to check which line we're on
PARTNER2:
		ldi		ZL, low(PARTNER2_BEG<<1)	; Load left-shited PARTNER2_BEG low byte into ZL
		ldi		ZH, high(PARTNER2_BEG<<1)	; Load left-shited PARTNER2_BEG high byte into ZH
CHECKLINES:
		cpi		countout, $01				; Checks if countout is a 1 for line 1
		breq	LINE1						; If true branches to LINE1
		cpi		countout, $02				; Check if countout is a 2 for line 2
		breq	LINE2						; If true branches to LINE2
		rjmp	PARTNER_EXIT				; Countout wasn't setup correctly jump to PARTNER_EXIT
LINE1:
		ldi		YL, low(LCDLn1Addr)			; Load the LCDLn1Addr into YL low byte which points
											; to the beggining of line1
		ldi		YH, high(LCDLn1Addr)		; Load the LCDLn1Addr into YH high byte which points
											; to the beggining of line1
		rjmp	STARTWRITING				; Jump to STARTWRITING
LINE2:
		ldi		YL, low(LCDLn2Addr)			; Load the LCDLn2Addr into YL low byte which points
											; to the beggining of line2
		ldi		YH, high(LCDLn2Addr)		; Load the LCDLn2Addr into YH high byte which points
											; to the beggining of line2
STARTWRITING:
		ldi		countin, $0F				; Set out countin counter to start at 16
WRITELINES:
		lpm		mpr, Z+						; Load program memory from Z into mpr and post-inc Z
		st		Y+, mpr						; Store mpr into Y and post-inc Y
		dec		countin						; Decrement our countin
		brne	WRITELINES					; If not equal to 0 start loop again

		cpi		countout, $01				; Checks if we wrote to line 1
		breq	LCDWR1						; If true branch to LCDWR1 fucntion
		cpi		countout, $02				; Checks if we wrote to line 2
		breq	LCDWR2						; If true branch to LCDWR2 fucntion
		rjmp	PARTNER_EXIT				; Countout wasn't setup correctly jump to PARTNER_EXIT
LCDWR1:
		rcall	LCDWrLn1					; Call the LCDWrLn1 fucntion to write line 1
		rjmp	PARTNER_EXIT				; Jump to PARTNER_EXIT
LCDWR2:
		rcall	LCDWrLn2					; Call the LCDWrLn2 fucntion to write line 2
PARTNER_EXIT:
ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
PARTNER1_BEG:
.DB		"BRADLEY HEENK   "				; Declaring data in ProgMem
PARTNER1_END:

PARTNER2_BEG:
.DB		"AARON VAUGHAN   "				; Declaring data in ProgMem
PARTNER2_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"				; Include the LCD Driver
