;
;MSX1 FPGA project
;
;Copyright (c) 2016 Fabio Belavenuto
;
;This program is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 3 of the License, or
;(at your option) any later version.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Technical info:
; 7B00h~7EFFh	: SPI data transfer window (read/write)
; 7FF0h			: Interface status and card select register (read/write)
;	<read>
;	b0	: 1=SD disk was changed
;	b1	: 0=SD card present
;	b2	: 1=Write protecton enabled for SD card
;	b3-7: Reserved for future use. Must be masked out from readings.
;	<write>
;	b0	: SD card chip-select (0=selected)

	.module mmc
	.optsdcc -mz80

	.area _DATA
mmc_type:	
	.ds 1

	.area	_CODE

SPI_CTRL = 0x7FF0;
SPI_DATA = 0x7B00;

; Comandos SPI:
CMD0	= 0  | 0x40
CMD1	= 1  | 0x40
CMD8	= 8  | 0x40
CMD9	= 9  | 0x40
CMD10	= 10 | 0x40
CMD12	= 12 | 0x40
CMD16	= 16 | 0x40
CMD17	= 17 | 0x40
CMD18	= 18 | 0x40
CMD24	= 24 | 0x40
CMD25	= 25 | 0x40
CMD55	= 55 | 0x40
CMD58	= 58 | 0x40
ACMD23	= 23 | 0x40
ACMD41	= 41 | 0x40


; ------------------------------------------------
; unsigned char MMC_IsPresent();
;
_MMC_IsPresent::
	ld		a, (SPI_CTRL)
	ld		l, #1
	and		#0x02						; Is there an SD Card in the slot?
	jr z,	.ispresent
	ld		l, #0
.ispresent:
	ld		a, l
	ret

; ------------------------------------------------
; Algoritmo para inicializar um cartao SD
; ------------------------------------------------
; unsigned char MMC_Init();
;
_MMC_Init::
	ld		a, (SPI_CTRL)
	and		#0x02						; Is there an SD Card in the slot?
	jr nz,	deuerroi
	ld		a, #0xFF
	ld		(SPI_CTRL), a				; desabilita SD
	ld		b, #10						; enviar 80 pulsos de clock com cartao desabilitado
enviaClocksInicio:
	ld		a, #0xFF					; manter MOSI em 1
	ld		(SPI_DATA), a
	djnz	enviaClocksInicio
	ld		a, #0xFE
	ld		(SPI_CTRL), a				; habilita SD
	ld		b, #16						; 16 tentativas para CMD0
SD_SEND_CMD0:
	ld		a, #CMD0					; primeiro comando: CMD0
	ld		de, #0
	push	bc
	call	SD_SEND_CMD_2_ARGS_TEST_BUSY
	pop		bc
	jp nc,	testaSDCV2					; cartao respondeu ao CMD0, pula
	djnz	SD_SEND_CMD0
	ld		a, #0xFF
	ld		(SPI_CTRL), a				; desabilita SD
	ld		a, #0						; cartao nao respondeu ao CMD0, retornar 0
	ret
testaSDCV2:
	ld		a, #CMD8
	ld		de, #0x1AA
	call	SD_SEND_CMD_2_ARGS_GET_R3
	ld		hl, #SD_SEND_CMD1			; HL aponta para rotina correta
	jr c,	.pula4						; cartao recusou CMD8, enviar comando CMD1
	ld		hl, #SD_SEND_ACMD41			; cartao aceitou CMD8, enviar comando ACMD41
.pula4:
	ld		bc, #120					; 120 tentativas
.loop:
	push	bc
	call	.jumpHL						; chamar rotina correta em HL
	pop		bc
	jp nc,	iniciou
	djnz	.loop
	dec		c
	jr nz,	.loop
deuerroi:
	ld		a, #0xFF
	ld		(SPI_CTRL), a				; desabilita SD
	ld		a, #0						; erro, retornar 0
	ret
.jumpHL:
	jp		(hl)						; chamar rotina correta em HL
iniciou:
	ld		a, #CMD58					; ler OCR
	ld		de, #0
	call	SD_SEND_CMD_2_ARGS_GET_R3	; enviar comando e receber resposta tipo R3
	jr c,	deuerroi
	ld		a, b						; testa bit CCS do OCR que informa se cartao eh SDV1 ou SDV2
	and		#0x40
	ld		(mmc_type), a				; salva informacao da versao do SD (V1 ou V2)
	call z,	mudarTamanhoBlocoPara512	; se bit CCS do OCR for 1, é cartao SDV2 (Block address - SDHC ou SDXD)
										; e nao precisamos mudar tamanho do bloco para 512
	ld		a, #0xFF
	ld		(SPI_CTRL), a				; desabilita SD
	ld		a, (mmc_type)				; retornar tipo de cartao
	cp		#0x40
	ld		a, #3
	ret z
	ld		a, #2
	ret

; ------------------------------------------------
; Setar o tamanho do bloco para 512 se o cartao
; for SDV1
; ------------------------------------------------
mudarTamanhoBlocoPara512:
	ld		a, #CMD16
	ld		bc, #0
	ld		de, #512
	jr		SD_SEND_CMD_GET_ERROR


; ------------------------------------------------
; Ler um bloco de 512 bytes do cartao
; ------------------------------------------------
; unsigned char MMC_Read(unsigned long lba, unsigned int *buffer) __sdcccall(0)
_MMC_Read::
	ld		iy, #0
	add		iy, sp
	ld		e, 2(iy)
	ld		d, 3(iy)
	ld		c, 4(iy)
	ld		b, 5(iy)					; BCDE=LBA
	ld		l, 6(iy)
	ld		h, 7(iy)					; HL=*buffer

	ld		a, #0xFE
	ld		(SPI_CTRL), a				; habilita SD
	ld		a, (mmc_type)				; verificar se eh SDV1 ou SDV2
	or		a
	call z,	blocoParaByte			; se for SDV1 converter blocos para bytes
	ld		a, #CMD17					; ler somente um bloco com CMD17 = Read Single Block
	call	SD_SEND_CMD_GET_ERROR
	jr		nc, .ok2
.erro2:
	ld		l, #0						; informar erro
	ret
.ok2:
	call	WAIT_RESP_FE
	jr c,	.erro2
	ex		de, hl						; DE = destiny
	ld		hl, #SPI_DATA				; HL = source
	ld		bc, #512					; BC = 512 times
 	ldir
	ld		a, (SPI_DATA)				; descarta CRC
	ld		a, (SPI_DATA)
	ld		l, #1						; OK
	ret

; ------------------------------------------------
; Converte blocos para bytes. Na pratica faz
; BC DE = (BC DE) * 512
; ------------------------------------------------
blocoParaByte:
	ld		b, c
	ld		c, d
	ld		d, e
	ld		e, #0
	sla		d
	rl		c
	rl		b
	ret

; ------------------------------------------------
; Enviar CMD1 para cartao. Carry indica erro
; Destroi AF, BC, DE
; ------------------------------------------------
SD_SEND_CMD1:
	ld		a, #CMD1
SD_SEND_CMD_NO_ARGS:
	ld		bc, #0
	ld		d, b
	ld		e, c
SD_SEND_CMD_GET_ERROR:
	call	SD_SEND_CMD
	or		a
	ret	z								; se A=0 nao houve erro, retornar
	; fall throw

; ------------------------------------------------
; Informar erro
; Nao destroi registradores
; ------------------------------------------------
setaErro:
	scf
	ret

; ------------------------------------------------
; Enviar comando ACMD41
; ------------------------------------------------
SD_SEND_ACMD41:
	ld		a, #CMD55
	call	SD_SEND_CMD_NO_ARGS
	ld		a, #ACMD41
	ld		bc, #0x4000
	ld		d, c
	ld		e, c
	jr		SD_SEND_CMD_GET_ERROR

; ------------------------------------------------
; Enviar comando em A com 2 bytes de parametros
; em DE e testar retorno BUSY
; Retorna em A a resposta do cartao
; Destroi AF, BC
; ------------------------------------------------
SD_SEND_CMD_2_ARGS_TEST_BUSY:
	ld		bc, #0
	call	SD_SEND_CMD
	ld		b, a
	and		#0xFE						; testar bit 0 (flag BUSY)
	ld		a, b
	jr		nz, setaErro				; BUSY em 1, informar erro
	ret									; sem erros

; ------------------------------------------------
; Enviar comando em A com 2 bytes de parametros
; em DE e ler resposta do tipo R3 em BC DE
; Retorna em A a resposta do cartao
; Destroi AF, BC, DE, HL
; ------------------------------------------------
SD_SEND_CMD_2_ARGS_GET_R3:
	call	SD_SEND_CMD_2_ARGS_TEST_BUSY
	ret	c
	push	af
	call	WAIT_RESP_NO_FF
	ld		h, a
	call	WAIT_RESP_NO_FF
	ld		l, a
	call	WAIT_RESP_NO_FF
	ld		d, a
	call	WAIT_RESP_NO_FF
	ld		e, a
	ld		b, h
	ld		c, l
	pop		af
	ret

; ------------------------------------------------
; Enviar comando em A com 4 bytes de parametros
; em BC DE e enviar CRC correto se for CMD0 ou 
; CMD8 e aguardar processamento do cartao
; Destroi AF, BC
; ------------------------------------------------
SD_SEND_CMD:
	ld		(SPI_DATA), a
	push	af
	ld		a, b
	ld		(SPI_DATA), a
	ld		a, c
	ld		(SPI_DATA), a
	ld		a, d
	ld		(SPI_DATA), a
	ld		a, e
	ld		(SPI_DATA), a
	pop		af
	cp		#CMD0
	ld		b, #0x95					; CRC para CMD0
	jr z,	enviaCRC
	cp		#CMD8
	ld		b, #0x87					; CRC para CMD8
	jr z,	enviaCRC
	ld		b, #0xFF					; CRC dummy
enviaCRC:
	ld		a, b
	ld		(SPI_DATA), a
	jr		WAIT_RESP_NO_FF

; ------------------------------------------------
; Esperar que resposta do cartao seja $FE
; Destroi AF, B
; ------------------------------------------------
WAIT_RESP_FE:
	ld		b, #255						; n tentativas
.loop1:
	push	bc
	call	WAIT_RESP_NO_FF				; esperar resposta diferente de $FF
	pop		bc
	cp		#0xFE						; resposta é $FE ?
	ret	z								; sim, retornamos com carry=0
	djnz	.loop1
	scf									; erro, carry=1
	ret

; ------------------------------------------------
; Esperar que resposta do cartao seja diferente
; de $FF
; Destroi AF, BC
; ------------------------------------------------
WAIT_RESP_NO_FF:
	ld		bc, #65535					; n tentativas
.loop2:
	ld		a, (SPI_DATA)
	cp		#0xFF						; testa $FF
	ret	nz								; sai se nao for $FF
	djnz	.loop2
	dec		c
	jr nz,	.loop2
	ret
