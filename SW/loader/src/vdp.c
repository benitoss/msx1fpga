/*

MSX1 FPGA project

Copyright (c) 2016 Fabio Belavenuto

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "hardware.h"
#include "vdp.h"
#include "font.h"

/* Constants */
/*
Control Registers:

Reg/Bit  7     6     5     4     3     2     1     0
0        -     -     -     -     -     -     M2    EXTVID
1        4/16K BL    GINT  M1    M3    -     SI    MAG
2        -     -     -     -     PN13  PN12  PN11  PN10		L=0x0300(768)		S=0x0800(2048)	E=0x0AFF(2815)
3        CT13  CT12  CT11  CT10  CT9   CT8   CT7   CT6		L=0x0020(32)		S=0x0B00(2816)	E=0x0B20(2836)
4        -     -     -     -     -     PG13  PG12  PG11		L=0x0800(2048)		S=0x0000(000)	E=0x07FF(2047)
5        -     SA13  SA12  SA11  SA10  SA9   SA8   SA7
6        -     -     -     -     -     SG13  SG12  SG11
7        TC3   TC2   TC1   TC0   BD3   BD2   BD1   BD0

	PG = Pattern Gen 	S=0x0000 L=0x0800
	PN = Pattern Name	S=0x0800 L=0x0300
	CT = Color Table	S=0x0B00 L=0x0020
*/
static const uint8 init[8] = {0x00, 0xC0, 0x02, 0x2C, 0x00, 0x00, 0x00, 0xF7};

/* Variables */
static uint8 cx, cy, fg, bg;

//------------------------------------------------------------------------------
void vdp_writereg(uint8 reg, uint8 val)
{
	VDP_CMD = val;
	VDP_CMD = (reg & 0x07) | 0x80;
}

//------------------------------------------------------------------------------
void vdp_setaddr(uint8 rw, uint16 addr)
{
	VDP_CMD = addr & 0xFF;
	VDP_CMD = ((addr >> 8) & 0x3F) | ((rw & 0x01) << 6);
}

//------------------------------------------------------------------------------
void vdp_writedata(uint8 *source, uint16 addr, uint16 count)
{
	uint8 i;
	uint16 c;

	vdp_setaddr(1, addr);
	for (c = 0; c < count; c++) {
		VDP_DATA = source[c];
		for (i=0; i < 10; i++) ;
	}
}

//------------------------------------------------------------------------------
static void vdp_cursorinc()
{
	++cx;
	if (cx > 31) {
		cx = 0;
		++cy;
		if (cy > 23) {
			cy = 23;
//			vdp_rolatela();
		}
	}
}

//------------------------------------------------------------------------------
void vdp_init()
{
	uint8 i;
	uint16 c;

	for (i=0; i < 8; i++) {
		vdp_writereg(i, init[i]);
	}
	vdp_setaddr(1, 0);
	for (c=0; c < 256; c++)
		VDP_DATA = 0;					// 00-31
	vdp_writedata(font, 256, 768);		// 32-7F
	vdp_setaddr(1, 1024);
	for (c=0; c < 1024; c++)
		VDP_DATA = 0;
	cx = cy = 0;
	fg = 15;
	bg = 7;
	vdp_setaddr(1, 2048);
	for (c=0; c < 768; c++)
		VDP_DATA = ' ';
}

//------------------------------------------------------------------------------
void vdp_setcolor(uint8 border, uint8 background, uint8 foreground)
{
	uint8 i;
	uint8 v = ((foreground & 0x0F) << 4) | (background & 0x0F);

	vdp_writereg(7, ((foreground & 0x0F) << 4) | (border & 0x0F));
	vdp_setaddr(1, 0xB00);
	for (i=0; i < 32; i++) {
		VDP_DATA = v;
	}
	fg = foreground;
	bg = background;
}

//------------------------------------------------------------------------------
void vdp_cls()
{
	uint16 c;
	vdp_setaddr(1, 2048);
	for (c=0; c < 768; c++)
		VDP_DATA = ' ';
}

//------------------------------------------------------------------------------
void vdp_gotoxy(uint8 x, uint8 y)
{
	cx = x & 31;
	cy = y;
	if (cy > 23) cy = 23;
}

//------------------------------------------------------------------------------
void vdp_putcharxy(uint8 x, uint8 y, uint8 c)
{
	uint16 addr;

	cx = x & 31;
	cy = y;
	if (cy > 23) cy = 23;
	addr = 0x800 + cy*32 + cx;
	vdp_setaddr(1, addr);
	VDP_DATA = c;
	vdp_cursorinc();
}

//------------------------------------------------------------------------------
void vdp_putchar(uint8 c)
{
	if (c == '\n') {
		cx = 0;
		if (cy < 23) {
			++cy;
		}
	} else {
		vdp_putcharxy(cx, cy, c);
	}
}

//------------------------------------------------------------------------------
void vdp_putcharcolor(uint8 c, uint8 color)
{
	uint16 addr = 0xB00 + cx;
	uint8 v = ((color & 0x0F) << 4) | bg;
	vdp_setaddr(1, addr);
	VDP_DATA = v;
	vdp_putcharxy(cx, cy, c);
}

//------------------------------------------------------------------------------
void vdp_putstring(char *s)
{
	do {
		vdp_putchar(*s);
	} while(*++s);
}

//------------------------------------------------------------------------------
void puthex(uint8 nibbles, uint16 v)
{
	int i = (int8)nibbles - 1;
	while (i >= 0) {
		uint16 aux = (v >> (i << 2)) & 0x000F;
		uint8 n = aux & 0x000F;
		if (n > 9)
			vdp_putchar('A' + (n - 10));
		else
			vdp_putchar('0' + n);
		i--;
	}
}

//------------------------------------------------------------------------------
void puthex8(uint8 v)
{
	puthex(2, (uint16) v);
}

//------------------------------------------------------------------------------
void puthex16(uint16 v)
{
	puthex(4, v);
}

//------------------------------------------------------------------------------
void putdec(uint16 digits, uint16 v)
{
	uint8 fz = 0;
	while (digits > 0) {
		uint16 aux = v / digits;
		uint8 n = aux % 10;
		if (n != 0 || fz != 0) {
			vdp_putchar('0' + n);
			fz = 1;
		}
		digits /= 10;
	}
}

//------------------------------------------------------------------------------
void putdec8(uint8 v)
{
	putdec(100, (uint16) v);
}

//------------------------------------------------------------------------------
void putdec16(uint8 v)
{
	putdec(10000, v);
}


