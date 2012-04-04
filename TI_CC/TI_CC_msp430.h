//----------------------------------------------------------------------------
//  Description:  This file contains definitions specific to the specific MSP430
//  chosen for this implementation.  MSP430 has multiple interfaces capable
//  of interfacing to the SPI port; each of these is defined in this file.
//
//  The source labels for the definitions (i.e., "P3SEL") can be found in
//  msp430xxxx.h.
//
//  MSP430/CC1100-2500 Interface Code Library v1.0
//
//  K. Quiring
//  Texas Instruments, Inc.
//  July 2006
//  IAR Embedded Workbench v3.41
//----------------------------------------------------------------------------

#include "msp430x22x4.h"                     // Adjust this according to the
                                            // MSP430 device being used.

// SPI port definitions                     // Adjust the values for the chosen
#define TI_CC_SPI_USART0_PxSEL  P3SEL       // interfaces, according to the pin
#define TI_CC_SPI_USART0_PxDIR  P3DIR       // assignments indicated in the
#define TI_CC_SPI_USART0_PxIN   P3IN        // chosen MSP430 device datasheet.
#define TI_CC_SPI_USART0_SIMO   0x10   // changed for UART in F2274
#define TI_CC_SPI_USART0_SOMI   0x20
#define TI_CC_SPI_USART0_UCLK   0x01   //?

#define TI_CC_SPI_USART1_PxSEL  P5SEL  // not present in 2274
#define TI_CC_SPI_USART1_PxDIR  P5DIR
#define TI_CC_SPI_USART1_PxIN   P5IN
#define TI_CC_SPI_USART1_SIMO   0x02
#define TI_CC_SPI_USART1_SOMI   0x04
#define TI_CC_SPI_USART1_UCLK   0x08

#define TI_CC_SPI_USCIA0_PxSEL  P3SEL
#define TI_CC_SPI_USCIA0_PxDIR  P3DIR
#define TI_CC_SPI_USCIA0_PxIN   P3IN
#define TI_CC_SPI_USCIA0_SIMO   0x10
#define TI_CC_SPI_USCIA0_SOMI   0x20
#define TI_CC_SPI_USCIA0_UCLK   0x01

#define TI_CC_SPI_USCIA1_PxSEL  P7SEL  // not present in 2274
#define TI_CC_SPI_USCIA1_PxDIR  P7DIR
#define TI_CC_SPI_USCIA1_PxIN   P7IN
#define TI_CC_SPI_USCIA1_SIMO   0x02
#define TI_CC_SPI_USCIA1_SOMI   0x04
#define TI_CC_SPI_USCIA1_UCLK   0x08

#define TI_CC_SPI_USCIB0_PxSEL  P3SEL
#define TI_CC_SPI_USCIB0_PxDIR  P3DIR
#define TI_CC_SPI_USCIB0_PxIN   P3IN
#define TI_CC_SPI_USCIB0_SIMO   0x02
#define TI_CC_SPI_USCIB0_SOMI   0x04
#define TI_CC_SPI_USCIB0_UCLK   0x08

#define TI_CC_SPI_USCIB1_PxSEL  P3SEL  // not present in 2274
#define TI_CC_SPI_USCIB1_PxDIR  P3DIR
#define TI_CC_SPI_USCIB1_PxIN   P3IN
#define TI_CC_SPI_USCIB1_SIMO   0x02
#define TI_CC_SPI_USCIB1_SOMI   0x04
#define TI_CC_SPI_USCIB1_UCLK   0x08

#define TI_CC_SPI_USI_PxDIR     P1DIR  // not present in 2274
#define TI_CC_SPI_USI_PxIN      P1IN
#define TI_CC_SPI_USI_SIMO      0x40
#define TI_CC_SPI_USI_SOMI      0x80
#define TI_CC_SPI_USI_UCLK      0x20

#define TI_CC_SPI_BITBANG_PxDIR P5DIR    // not present in 2274
#define TI_CC_SPI_BITBANG_PxOUT P5OUT
#define TI_CC_SPI_BITBANG_PxIN  P5IN
#define TI_CC_SPI_BITBANG_SIMO  0x02
#define TI_CC_SPI_BITBANG_SOMI  0x04
#define TI_CC_SPI_BITBANG_UCLK  0x08


//----------------------------------------------------------------------------
//  These constants are used to identify the chosen SPI and UART interfaces.
//----------------------------------------------------------------------------
#define TI_CC_SER_INTF_NULL    0
#define TI_CC_SER_INTF_USART0  1
#define TI_CC_SER_INTF_USART1  2
#define TI_CC_SER_INTF_USCIA0  3
#define TI_CC_SER_INTF_USCIA1  4
#define TI_CC_SER_INTF_USCIB0  5
#define TI_CC_SER_INTF_USCIB1  6
#define TI_CC_SER_INTF_USI     7
#define TI_CC_SER_INTF_BITBANG 8
