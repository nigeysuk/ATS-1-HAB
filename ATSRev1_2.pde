// ATS-1 Arduino Flight Code 
// By Nigel Smart - nigel@nigey.co.uk
// Rev 1.2 - 7th April 2011
// Additional OneWire code by James Coxon & fsphil
// Compiled with the help of UKHAS members from #highaltitude @ irc.freenode.net

#define TX0 7
#define TX1 5
#include <OneWire.h> //OneWire Temp Sensor Library
#include <stdio.h>
#include <util/crc16.h>
#include <TinyGPS.h>
#include <NewSoftSerial.h>

OneWire ds(8); // DS18x20 Temperature chip i/o OneWire

//Temp Sensor variables
byte address0[8] = {
  0x10, 0xB6, 0xBE, 0x30, 0x2, 0x8, 0x0, 0xD2}; // Internal DS18B20+ Temp Sensor - Address 0x10 0xB6 0xBE 0x30 0x2 0x8 0x0 0xD2
byte address1[8] = {
  0x10, 0x6E, 0xBD, 0x30, 0x2, 0x8, 0x0, 0xF9}; // External DS18B20+ Temp Sensor - Address 0x10 0x6E 0xBD 0x30 0x2 0x8 0x0 0xF9

int temp0 = 0, temp1 = 0;

//Set up the timers
long previousMillis = 0;
long previousLedMillis = 0;
long interval = 3000;   
long ledInterval = 500;
int ledState = LOW;

//Get the temperature data from OneWire sensor network

int getTempdata(byte sensorAddress[8]) {
  int HighByte, LowByte, TReading, SignBit, Tc_100, Whole;
  byte data[12], i, present = 0;

  ds.reset();
  ds.select(sensorAddress);
  ds.write(0x44,1);         //Start conversion, with parasite power on at the end

  // 3000ms Delay

  present = ds.reset();
  ds.select(sensorAddress);    
  ds.write(0xBE);         // Read Scratchpad

  for ( i = 0; i < 9; i++) {           // We need 9 bytes
    data[i] = ds.read();
  }
  LowByte = data[0];
  HighByte = data[1];
  TReading = (HighByte << 8) + LowByte;
  SignBit = TReading & 0x8000;  // Test most sig bit
  if (SignBit) // negative
  {
    TReading = (TReading ^ 0xffff) + 1; // 2's comp
  }

  if (sensorAddress[0] == 0x10) {
    Tc_100 = TReading * 50;    // Multiply by (100 * 0.0625) or 6.25
  }
  else { 
    Tc_100 = (6 * TReading) + TReading / 4;    // Multiply by (100 * 0.0625) or 6.25
  }

  Whole = Tc_100 / 100;  // Separate off the whole and fractional portions

  if (SignBit) // If its negative
  {
    Whole = Whole * -1;
  }
  return Whole;
}

//Let's configure some GPS settings

NewSoftSerial nss(2, 3);
TinyGPS gps;

char msg[120];
int count = 1;

uint16_t crccat(char *msg)
{
  uint16_t x;
  for(x = 0xFFFF; *msg; msg++)
    x = _crc_xmodem_update(x, *msg);
  snprintf(msg, 8, "*%04X\n", x);
  return(x);
}

void setup(void) {
  // Initialize inputs/outputs

  pinMode(13, OUTPUT); 
  pinMode(12, OUTPUT);
  digitalWrite(12,HIGH);

  // Setup the GPS serial port
  Serial.begin(115200);
  nss.begin(9600);

  count = 1;

  pinMode(TX0, OUTPUT);
  pinMode(TX1, OUTPUT);

  rtty_send(".... Starting Testing ATS-1 1 Pin RTTY....\n");

}
void loop(void) {

  long lat, lng;
  unsigned long time;
  unsigned long currentMillis = millis();
  /* Got any data yet? */
  if(nss.available() <= 0) return;
  if(!gps.encode(nss.read())) return;

  /* Yes, prepare the string */
  gps.get_position(&lat, &lng, NULL);
  gps.get_datetime(NULL, &time, NULL);
  int numbersats = 99;
  numbersats = gps.sats();
  if(currentMillis - previousLedMillis > ledInterval) {

    if (lat > 0){
      if (ledState == LOW)
        ledState = HIGH;
      else
        ledState = LOW;
      digitalWrite(12,ledState);
    }
    else{ 
      digitalWrite(12,HIGH);
    }
    previousLedMillis = currentMillis;
  }


  if(currentMillis - previousMillis > interval) {

    snprintf(msg, 120,
    "$$ATS1,%i,%02li:%02li:%02li,%s%li.%05li,%s%li.%05li,%li,%i,%i,%i",
    count++, time / 1000000, time / 10000 % 100, time / 100 % 100,
    (lat >= 0 ? "" : "-"), labs(lat / 100000), labs(lat % 100000),
    (lng >= 0 ? "" : "-"), labs(lng / 100000), labs(lng % 100000),
    gps.altitude() / 100,
    getTempdata(address0),
    getTempdata(address1),
    numbersats


      );
    /* Append the checksum, skipping the $$ prefix */
    crccat(msg + 2);
    
   	/* Transmit it! */



    //char msg[100];
    //Serial.print(msg);
    rtty_send(msg);
    
    previousMillis = currentMillis;
  }

}
// --------------------------------------------------------------------------------- 
// RTTY Code 
// 
// Code to send strings via RTTY.  The RTTY parameters are defined by constants 
// below. 
// --------------------------------------------------------------------------------- 
 
// The number of bits per character (7), number of start bits (1), number of stop bits (2) 
// and the baud rate. 
 
#define ASCII 7  
#define START 1 
#define STOP 2 
#define BAUD 50 
#define INTER_BIT_DELAY (1000/BAUD) 

// rtty_send: sends a null-terminated string via radio to the ground trackers 
void rtty_send( char * s ) // The null-terminated string to transmit 
{ 
  char c; 
  while ( c = *s++ ) { 
    int i; 
    for ( i = 0; i < START; ++i ) { 
      rtty_bit(0); 
    } 
     
    int b;    
    for ( i = 0, b = 1; i < ASCII; ++i, b *= 2 ) { 
      rtty_bit(c&b); 
    } 
     
    for ( i = 0; i < STOP; ++i ) { 
      rtty_bit(1); 
    } 
  } 
  
  // Note that when idling RTTY specifies that it be in the 'mark' state (or 1).  This 
  // is achieved by the stop bits that were sent at the end of the last character.  
} 
 
// rtty_bit: sends a single bit via RTTY 
void rtty_bit(int b) // Send 0 if b is 0, 1 if otherwise 
{ 
  digitalWrite(TX0,(b>0)?HIGH:LOW); 
  digitalWrite(TX1,(b>0)?LOW:HIGH); 
  delay(INTER_BIT_DELAY); 
}
  
