/*
    Copyright (C) 2010  Daniel Richman & Simrun Basuita

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    For a full copy of the GNU General Public License, 
    see <http://www.gnu.org/licenses/>.
*/

/* NB: Read note below about changing the phone number ! */

/* From hexdump.h ALIEN Project Daniel Richman */

#include <NewSoftSerial.h>  
#define rxPin 2  //T68 TX
#define txPin 3  //T68 RX  
NewSoftSerial nss =  NewSoftSerial(rxPin, txPin); 

#define num_to_char(number)   ((number) < 10 ?                           \
                                               ('0' + (number)) :        \
                                               (('A' - 10) + (number)) )

/* To select the 4 bits we do this */
#define first_four(byte)       (0x0F & (byte))

/* Last four: Shift left to get to a number < 16 */
#define  last_four(byte)      ((0xF0 & (byte)) >> 4)

/* The MSB goes first. */
#define hexdump_a(byte)  num_to_char( last_four(byte))
#define hexdump_b(byte)  num_to_char(first_four(byte))

void hexdump_byte(unsigned char byte)
{
  nss.print(hexdump_a(byte), BYTE);
  nss.print(hexdump_b(byte), BYTE);
}

void send_sms(char *data)
{
  size_t data_length, x;
  char c, l;
  long i;
  long n;

  data_length = strlen(data);
  i = data_length * 7;

  /* Round i up to a multiple of 8 */
  if (i & 0x07) i = (i & ~0x07) + 0x08;

  /* Calculate the number of message octets */
  i = i / 8;

  nss.println("AT+CMGF=0");
  delay(1500);
  nss.print("AT+CMGS=");
  delay(1500);
  nss.println(i + 14);
  delay(1500);

  /*
   * You will need to replace the xs with your telephone number.
   * First replace the first x with C for a 12 digit international number,
   * or B for an eleven digit one.
   * Next replace the stream of 12 xs with your phone number. It's in a
   * weird order; for +441234567890 you would want 442143658709 (note
   * reversal of pairs).
   * Full example: 0011000C914421436587090000AA
   */

  nss.print("0011000B914487693917300000AA");
  hexdump_byte(data_length & 0xFF);

  /* from sms_example_v2.c ALIEN Project Daniel Richman */
  l = 0;
  n = 0;

  for (x = 0; x < data_length; x++)
  {
    if (data[x] == '$')  data[x] = 0x02;

    n |= (data[x] & 0x7F) << l;
    l += 7;

    if (l >= 8)
    {
      hexdump_byte(n & 0xFF);
      l -= 8;
      n >>= 8;
    }
  }

  if (l != 0)
  {
    hexdump_byte(n & 0xFF);
  }

  nss.println(0x1A, BYTE);
}
void setup(void) {
  
  Serial.begin(115200);
  nss.begin(9600);
  send_sms("hello world");
}
void loop() { }
