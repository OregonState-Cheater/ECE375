/*
 * Aaron_Vaughan_and_Bradley_Heenk_Lab2_challengecode.c
 *
 * About: a program to make tekbot push objects
 * Created: 10/12/2019 12:01:12 PM
 * Author : Aaron Vaughan and Bradley Heenk
 */ 
/*
This 
PORT MAP
Port B, Pin 4 -> Output -> Right Motor Enable
Port B, Pin 5 -> Output -> Right Motor Direction
Port B, Pin 7 -> Output -> Left Motor Enable
Port B, Pin 6 -> Output -> Left Motor Direction
Port D, Pin 1 -> Input -> Left Whisker
Port D, Pin 0 -> Input -> Right Whisker
*/
#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

uint8_t wskrL = 0;
uint8_t wskrR = 0;

void bump()
{
	_delay_ms(250);        // wait for 0.25 s
	PORTB = 0b00000000;     // move backward
	_delay_ms(500);        // wait for 0.25 s
}
void turnL()
{
	PORTB = 0b00000000;     // move backward
	_delay_ms(250);        // wait for 0.25 s
	PORTB = 0b00100000;     // turn left
	_delay_ms(500);        // wait for 0.5 s
};

void turnR()
{
	PORTB = 0b00000000;     // move backward
	_delay_ms(250);        // wait for 0.25 s
	PORTB = 0b01000000;     // turn right
	_delay_ms(500);			//wait for 0.5 s
};

int main(void)
{
	DDRB = 0b11110000;      // configure Port B pins for input/output
	PORTB = 0b11110000;     // set initial value for Port B outputs
	DDRD = 0b00000000;		// configure Port B pins for input/output
	PORTD = 0b11111111;		// set initial value for Port D inputs
	
	
	// (initially, disable both motors)

	while (1) { // loop forever
		
		PORTB = 0b01100000;     // make TekBot move forward

		wskrL = PIND & 0x02;	// ignore all pins except pin 1
		wskrR = PIND & 0x01;	// ignore all pins except pin 0
		
		if((wskrL | wskrR) == 0x0)
		{
			turnR();		
		}
		
// 		else if (wskrR == 0x00)		// if the right whisker button is pressed
// 		turnR();			// execute the turn left command
// 		
// 		else if (wskrL == 0x00)		// if the right whisker button is pressed
// 		turnL();			// execute the turn right command
	}
}