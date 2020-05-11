/*
 * a4.c
 *
 * Created: 7/27/2018 3:07:08 PM
 * Author : shengjies
 */ 


#include "CSC230.h"
#include <string.h> //Include the standard library string functions
#include <stdio.h>


#define  ADC_BTN_RIGHT 0x032
#define  ADC_BTN_UP 0x0C3
#define  ADC_BTN_DOWN 0x17C
#define  ADC_BTN_LEFT 0x22B
#define  ADC_BTN_SELECT 0x316



//This global variable is used to count the number of interrupts
//which have occurred. Note that 'int' is a 16-bit type in this case.
int interrupt_count = 0;
char str[100];
int Array[5] = {0,0,0,0,0};
int a1[5] = {0,0,0,0,0};
int a2[5] = {0,0,0,0,0};
int l = 0;

//Define the ISR for the timer 0 overflow interrupt.
ISR(TIMER0_OVF_vect){
	interrupt_count++;
	if (interrupt_count >= 6){
		interrupt_count -= 6;
		char str[100];
		//Copy some data into the string
		increment_time(Array);
		sprintf(str, "Time: %d%d:%d%d:%d   ", Array[0],Array[1],Array[2],Array[3],Array[4]);
		lcd_xy(0,0);
		lcd_puts(str);
	}
}

//increment_time is used to increase number
void increment_time(int A[]){
	int maximum_values[5] = {9, 9, 5, 9, 9};
	int i;
	//Add one to the last index (T)
	A[4] += 1;
	//Now work backwards if any digit exceeded the limits
	//in the array above.
	for (i = 4; i >= 0; i--){
		if (A[i] > maximum_values[i]){
			A[i] = 0;
			A[i-1] += 1;
		}
	}
	//If A[0] exceeded 9, then wrap around to 0.
	if (A[0] > maximum_values[0]){
		A[0] = 0;
	}
		
}
	
	

// timer0_setup()
// Set the control registers for timer 0 to enable
// the overflow interrupt and set a prescaler of 1024.
void timer0_setup(){
	//You can also enable output compare mode or use other
	//timers (as you would do in assembly).
	TIMSK0 = 0x01;
	TCNT0 = 0x00;
	TCCR0A = 0x00;
	TCCR0B = 0x05; //Prescaler of 1024
}

//read the adc
unsigned short poll_adc(){
	unsigned short adc_result = 0; //16 bits
	ADCSRA |= 0x40;
	while((ADCSRA & 0x40) == 0x40); //Busy-wait
	_delay_ms(50);
	unsigned short result_low = ADCL;
	unsigned short result_high = ADCH;
	
	adc_result = (result_high<<8)|result_low;
	return adc_result;
}


int main(){
	
	lcd_init();
	sprintf(str, "Time: 00:00:0   ");
	lcd_xy(0,0);
	lcd_puts(str);
	timer0_setup();

	//ADC Set up
	ADCSRA = 0x87;
	ADMUX = 0x40;
	
	while(1){
		unsigned short adc_before = 0x03ff;
		unsigned short adc_result1 = poll_adc();
		if (adc_result1 < adc_before){
			do_adc(adc_result1);
			adc_before = 0x03ff;
			adc_result1 = poll_adc();
			
		} else {
			adc_before = adc_result1;
		}
	}

	return 0;
	
}

// do the things after button pressed
void do_adc(unsigned short adc){
	
		if (adc <= ADC_BTN_RIGHT){
			return;
		}else if(adc <= ADC_BTN_UP){
			if (l == 1){
				l = 0;
				for (int i = 0; i < 5; i++){
					a2[i] = 0;
				}
			}
			for (int i = 0; i < 5; i++){
				a1[i] = a2[i];
			}
			for (int i = 0; i < 5; i++){
				a2[i] = Array[i];
			}
			sprintf(str, "%d%d:%d%d:%d  %d%d:%d%d:%d",a1[0],a1[1],a1[2],a1[3],a1[4],a2[0],a2[1],a2[2],a2[3],a2[4]);
			lcd_xy(0,1);
			lcd_puts(str);
			return;
		}else if(adc <= ADC_BTN_DOWN){
			for (int i = 0; i < 5; i++){
				a1[i] = 0;
				a2[i] = 0;
			}
			sprintf(str, "                ");
			lcd_xy(0,1);
			lcd_puts(str);
			return;
		}else if(adc <= ADC_BTN_LEFT){
			cli();
			l = 1;
			for (int i = 0; i < 5; i++){
				Array[i] = 0;
			}
			sprintf(str, "Time: 00:00:0   ");
			lcd_xy(0,0);
			lcd_puts(str);
			return;
		}else if(ADC <= ADC_BTN_SELECT){
			if ((SREG>>7) == 0) sei(); 
			else  cli(); 
			return;
		}else{
			return;
		}
	
}