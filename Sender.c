//MatLab controlled Car

//SENDING VERSION

#include "TI_CC/include.h"


// bit masks for P1 on the RF2500 target board
#define LED1_MASK              0x01	
#define LED2_MASK              0x02
#define SW1_MASK               0x04 
#define flashcount			   5000
#define delaycount			   1000

extern char paTable[];		// power table for C2500
extern char paTableLen;

char txBuffer[51];
char rxBuffer[4];
unsigned int i,j;
unsigned int count;

char TXchars[50];
int countint = 0;
int number = 0;


void main (void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT

//CONFIGURE UART SERIAL
  BCSCTL1 = CALBC1_1MHZ;                    // Set DCO
  DCOCTL = CALDCO_1MHZ;
  P3SEL = 0x30;                             // P3.4,5 = USCI_A0 TXD/RXD
  UCA0CTL1 |= UCSSEL_2;                     // SMCLK
  UCA0BR0 = 104;                            // 1MHz 9600
  UCA0BR1 = 0;                              // 1MHz 9600
  UCA0MCTL = UCBRS0;                        // Modulation UCBRSx = 1
  UCA0CTL1 &= ~UCSWRST;                     // **Initialize USCI state machine**
  IE2 |= UCA0RXIE;                          // Enable USCI_A0 RX interrupt


  
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

//Interrupt handler for serial read
#pragma vector=USCIAB0RX_VECTOR
__interrupt void USCI0RX_ISR(void)
{
  while (!(IFG2&UCA0TXIFG));				// USCI_A0 TX buffer ready?
  if(UCA0RXBUF != 10 || !countint){			// skip the stop filler characters unless it is the first one
  TXchars[countint] = UCA0RXBUF;            // save the character to the array
  countint++;									
  }
  UCA0TXBUF = UCA0RXBUF;                    // TX -> RXed character for confirmation to the GUI
 
  																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																				
  if((countint-1) >= TXchars[0] && UCA0RXBUF == 10){	//When all of the characters have been read in
  	number = countint-1;								//Get the number of instructions
  	TXchars[0] = 90;									//Reset number of instructions
  	countint = 0;										//Reset counter
  	
	// After the serial read is done 
	// wireless sending							
  txBuffer[0] = 50;                           // Packet length
  txBuffer[1] = 0x01;                        // Packet address
  txBuffer[2] = number;						//number of instructions
  
  //store the characters to be sent in the txBuffer
  for (j = 1; j <= number; j++){
  	txBuffer[j+2] = TXchars[j];
  }
  

  RFSendPacket(txBuffer, 51);                 // Send the packet value over RF
  P1OUT ^= LED2_MASK;			 			 // toggle LED2 on THIS board
  
  P1IFG &= ~SW1_MASK;                        //Clr flag that caused int
  P2IFG &= ~TI_CC_GDO0_PIN;                  // After pkt TX, this flag is set.
 
  }

  
}


// ISR for received packet
// The ISR assumes the int came from the pin attached to GDO0 and therefore
// does not check the other seven inputs.  Interprets this as a signal from
// CCxxxx indicating packet received.

// This is triggered when the car is done with its instruction set and sends a confirmation of completion
#pragma vector=PORT2_VECTOR
__interrupt void port2_ISR (void)
{
  char len=3;                               // Len of pkt to be RXed (only addr
                                            // plus data; size byte not incl b/c
                                            // stripped away within RX function)
  if (RFReceivePacket(rxBuffer,&len)){       // Fetch packet from CCxxxx
  	while (!(IFG2&UCA0TXIFG));			
  	UCA0TXBUF = rxBuffer[1];			//Send the character recieved character back up through the UART to unlock the GUI
  	P1OUT ^= LED1_MASK;					//Toggle RED LED
  	
  }
  P2IFG &= ~TI_CC_GDO0_PIN;                 // Clear flag
}


