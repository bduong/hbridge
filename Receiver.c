//MatLab controlled Car

//RECEIVING VERSION


#include "TI_CC/include.h"


// bit masks for P1 on the RF2500 target board
#define LED1_MASK              0x01	
#define LED2_MASK              0x02
#define SW1_MASK               0x04 
#define flashcount			   5000
#define delaycount			   1000
#define disttime			   500

//bit marcos for decoding
#define OPCODE(instr) 		  	(instr & (0x60))
#define ARGUMENT(instr)			(instr & (0x1F))


extern char paTable[];		// power table for C2500
extern char paTableLen;

char txBuffer[4];
char rxBuffer[51];
unsigned int i,j,k;
unsigned long int time;

char RXchars[50];
int number = 0;
char op, arg;




void main (void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT

//CONFIGURE SPI WIRELESS
  P2SEL &= 0x3F;							//clear select bits for XIN,XOUT, which are set by default

  TI_CC_SPISetup();                         // Initialize SPI port
  TI_CC_PowerupResetCCxxxx();               // Reset CCxxxx
  writeRFSettings();                        // Write RF settings to config reg
  TI_CC_SPIWriteBurstReg(TI_CCxxx0_PATABLE, paTable, paTableLen);//Write PATABLE

  // Configure ports -- switch inputs, LEDs, GDO0 to RX packet info from CCxxxx
 
  // Input switch (on target board).
  // Pushing switch pulls down the input bit SW1 and triggers an input interrupt
  //   on port 1.  The handler sends a message to the second board.
  
  P1REN |= SW1_MASK; //  enable pullups on SW1
  P1OUT |= SW1_MASK;
  P1IES = SW1_MASK; //Int on falling edge	
  P1IFG &= ~(SW1_MASK);//Clr flag for interrupt
  P1IE = SW1_MASK;//enable input interrupt
  
  // Configure LED outputs on port 1
  P1DIR = LED1_MASK + LED2_MASK ; //Outputs
  P1OUT |= (LED1_MASK+LED2_MASK); // both lights on
   
  //Configure OutPut Pins on Port 2
  P2DIR |= 0x1F; //Outputs
  P2OUT &= ~0x1F; //All pins to 0
  
  // setup for interrupts related to receipt of a message from the CC2500
  
  TI_CC_GDO0_PxIES |= TI_CC_GDO0_PIN;       // Int on falling edge of GDO0 (end of pkt)
  TI_CC_GDO0_PxIFG &= ~TI_CC_GDO0_PIN;      // Clear Interrupt flag for GDO0 pin
  TI_CC_GDO0_PxIE |= TI_CC_GDO0_PIN;        // Enable interrupt on end of packet

  // turn on the CC2500 in receive mode
  TI_CC_SPIStrobe(TI_CCxxx0_SRX);           // Initialize CCxxxx in RX mode.
                                            // When a pkt is received, it will
                                            // signal on GDO0 and wake CPU
  _BIS_SR(LPM3_bits + GIE);                 // Enter LPM3, enable interrupts
}


// ISR for received packet
// The ISR assumes the int came from the pin attached to GDO0 and therefore
// does not check the other seven inputs.  Interprets this as a signal from
// CCxxxx indicating packet received.

//This is triggered when the packets of instructions are sent from the SENDER 
#pragma vector=PORT2_VECTOR
__interrupt void port2_ISR (void)
{
  char len=50;                               // Len of pkt to be RXed (only addr
                                            // plus data; size byte not incl b/c
                                            // stripped away within RX function)
  if (RFReceivePacket(rxBuffer,&len)){       // Fetch packet from CCxxxx

  	number = rxBuffer[1];					//the number of instructions is stored in the first element
  	for (j = 0; j < number;j++){	
  		RXchars[j] = rxBuffer[j+2];			//store the instructions into an array
  	}
  	
 //PIN 1 (2.0) - Forward
 //PIN 2 (2.1) - Left
 //PIN 3 (2.2) - Backward
 //PIN 4 (2.3) - Right
 //PIN 5 (2.4) - Detonate
  	
  	//run each instruction one at a time
  	for (k = 0; k < number; k++){
		//get the opcode and argument through bit masks
  		op =OPCODE(RXchars[k]);
  		arg = ARGUMENT(RXchars[k]);
  		switch(op){
  			case 0x00:	// Stop/Detonate
				if(arg > 0){			//Argument is non-zero if command is detonate
					P2OUT &= ~(0x0F);	
					P2OUT |= 0x10;		
				}else
				{
					P2OUT &= ~0x1F;
				}
  				time = 0; 											
  				P1OUT ^= LED2_MASK;			 			 
  			break; 													
  			case 0x20: // Forward 									
  				P2OUT &= ~(0x17); 									
  				P2OUT |= 0x01; 										
  				while(time++ < disttime*arg); 						
  				P1OUT ^= LED2_MASK;			 			
  				P2OUT &= ~(0x01); 									
  				time = 0; 											
  			break; 													
  			case 0x40: // Backward 									
  				P2OUT &= ~(0x1B); 									
  				P2OUT |= 0x04; 										
  				while(time++ < disttime*arg); 						
  				P1OUT ^= LED2_MASK;			 			
  				P2OUT &= ~(0x04); 									
  				time = 0; 											
  			break; 													
  			case 0x60: //Turn 										
  			P2OUT &= ~(0x06);	
				if(arg > 0){			//Argument is non-zero if command is RIGHT
					P2OUT &= ~(0x02);
					P2OUT |= 0x09;
				}else{
					P2OUT &= ~(0x08);
					P2OUT |= 0x03;
				}
				while(time++ < disttime*31);
				P2OUT &= ~(0x19);
				time = 0;
			P1OUT ^= LED2_MASK;			 			
  			break;
			default: 
  				P2OUT &= ~(0x1F);
  				time = 0;			 			
  		}
		
  }

  	//When all of the instructions are done
  	//send confirmation of completed instructions
  	
  	P2IFG &= ~TI_CC_GDO0_PIN;                 // Clear flag
  	
  	txBuffer[0] = 2;
  	txBuffer[1] = 0x01;
  	txBuffer[2] = 0x11;						//Confirmation character
  	
  	RFSendPacket(txBuffer,3);
 	P1IFG &= ~SW1_MASK;                        //Clr flag that caused int
	P2IFG &= ~TI_CC_GDO0_PIN;                  // After pkt TX, this flag is set.
  	

  }
  P2IFG &= ~TI_CC_GDO0_PIN;                 // Clear flag
}


