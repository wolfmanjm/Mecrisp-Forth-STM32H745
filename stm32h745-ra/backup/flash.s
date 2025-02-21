@
@    Mecrisp-Stellaris - A native code Forth implementation for ARM-Cortex M microcontrollers
@    Copyright (C) 2013  Matthias Koch
@
@    This program is free software: you can redistribute it and/or modify
@    it under the terms of the GNU General Public License as published by
@    the Free Software Foundation, either version 3 of the License, or
@    (at your option) any later version.
@
@    This program is distributed in the hope that it will be useful,
@    but WITHOUT ANY WARRANTY; without even the implied warranty of
@    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@    GNU General Public License for more details.
@
@    You should have received a copy of the GNU General Public License
@    along with this program.  If not, see <http://www.gnu.org/licenses/>.
@

@ Schreiben und Löschen des Flash-Speichers im STM32H743.

@ In diesem Chip gibt es Flashschreibzugriffe mit wählbarer Breite -
@ so ist es diesmal ganz komfortabel. Leider gibt es nur weniger große
@ Sektoren, die getrennt gelöscht werden können.

@ Write and Erase Flash in STM32H745.
@ NOTE this currently only supports writing to the first 1MB flash bank
@  This is complex on this platform as the flash write is a minimum of a
@  flash word which is 256 bits or 16 half words or 32 bytes
@  as we know the area we are writing to is already erased we need to align
@  the flashword on the 256 bit boundary, read in the existing data,
@  then write the 16bits or 8bits we want in the correct place in the flash word
@  then flash the flashword

@ Porting: Rewrite this ! You need hflash! and - as far as possible - cflash!

.equ FLASH_Base, 0x52002000

.equ FLASH_ACR,     FLASH_Base + 0x00 @ Flash Access Control Register
.equ FLASH_KEYR,    FLASH_Base + 0x04 @ Flash Key Register
.equ FLASH_OPTKEYR, FLASH_Base + 0x08 @ Flash Option Key Register
.equ FLASH_CR,      FLASH_Base + 0x0C @ Flash Control Register
.equ FLASH_SR,      FLASH_Base + 0x10 @ Flash Status Register
.equ FLASH_CCR,     FLASH_Base + 0x14 @ Flash Clear Control Register
.equ FLASH_OPTCR,   FLASH_Base + 0x18 @ Flash Option Control Register

.equ flashOverwrite, 1

@ HACKALERT as I don't want to modify core to add a 32byte buffer
@ so I'm using a RAM area currently unused by anything
.equ FLASH_WORD_32, 0x20000000  @ DTCMRAM

.equ FLASH_ERROR_MSK, 0x00020000|0x00040000|0x00080000|0x00400000|0x00800000|0x01000000|0x04000000|0x10000000|0x00200000|0x02000000

@ return Z = 0 no error z = 1 error, errors bits in r2
check_flash_error:
	ldr 	r2, =FLASH_SR
    ldr 	r3, [r2]
    ldr 	r2, =FLASH_ERROR_MSK
	ands 	r3, r2
	bne  	1f
	bx		lr
	@ clear the error flags
1:	ldr 	r2, =FLASH_CCR
	ldr 	r4, =FLASH_ERROR_MSK
	str 	r4, [r2]
	movs 	r2, r3
	bx		lr

wait_for_last_operation:
	push    {lr}
	@ Wait For Last Operation QW flag bit2
	ldr 	r2, =FLASH_SR
1:  ldr 	r3, [r2]
	ands 	r3, #0x00000004
	bne 	1b
	bl 		check_flash_error @ check error flags
	beq 	3f
	pop     {pc}
	@ check end of operation flag 0x00010000
3:	ldr 	r2, =FLASH_SR
    ldr 	r3, [r2]
	ands 	r3, #0x00010000
	beq 	2f
	@ clear it
	ldr 	r2, =FLASH_CCR
	ldr 	r3, [r2]
    orr 	r3, #0x00010000
  	str  	r3, [r2]
2:  movs 	r2, #0
	pop     {pc}

@ flash the 32 byte flash line to flash at address in r0 (align to 32 bytes)
flash_line:
	push    {r0-r1, lr}
	BIC 	r0, #31
	@ do flash
	@ Unlock Flash Control
	ldr 	r2, =FLASH_KEYR
	ldr 	r3, =0x45670123
	str 	r3, [r2]
	ldr 	r3, =0xCDEF89AB
	str 	r3, [r2]
	@ Check it is unlocked
	ldr 	r2, =FLASH_CR
	ldr 	r3, [r2]
	ands 	r3, #0x00000001
	bne 	3f

	@ HAL does this, checks for any last operation to finish without errors
	bl 		wait_for_last_operation
	movs	r4, r2
	cmp 	r4, #0
	bne 	4f

 	@ Set PGBIT
 	ldr   	r1, =FLASH_CR
	ldr   	r4, [r1]
  	orr   	r4, #0x00000002
	str   	r4, [r1]

	ISB
	DSB

	@ Write to Flash from the flash line buffer 32 bytes
	ldr 	r2, =FLASH_WORD_32
	mov		r3, #8
1:  ldr 	r1, [r2], #4 @ read word from flash line buffer
	str 	r1, [r0], #4
	subs 	r3, #1
	bne 	1b

	ISB
	DSB

	bl 		wait_for_last_operation
	mov 	r4, r2			@ save the error in r4 for later

	@ Wait for Flash BUSY Flag to be cleared
	@ HAL does not do this
@	ldr r2, =FLASH_SR
@2:  ldr r3, [r2]
@	ands r3, #0x00010000
@	bne 2b

	@ clear PG bit
 	ldr   	r1, =FLASH_CR
	ldr   	r0, [r1]
  	bic   	r0, #0x00000002
	str   	r0, [r1]

	@ Lock Flash after finishing this
	ldr 	r2, =FLASH_CR
	ldr   	r1, [r2]
  	orr   	r1, #0x00000001		@ set bit
	str   	r1, [r2]

	@ check for any errors
	cmp 	r4, #0
	bne 	4f
	pop     {r0-r1, pc}

3: 	pop     {r0-r1, lr}
	Fehler_Quit "Error 1 writing flash !"

4: 	pushdatos			@ print out the error code we got
  	mov 	tos, r4
  	bl 		hexdot
	pop     {r0-r1, lr}
	Fehler_Quit "Error 2 writing flash !"

@ read the existing data in the flash that precedes the new value
@ then write the new value at offset in r3
read_line:
	mov 	r4, #8
	ldr 	r5, =FLASH_WORD_32
1:  ldr 	r6, [r2], #4 		@ read word from requested buffer aligned to 32bytes
	str 	r6, [r5], #4 		@ store word to flash line buffer
	subs 	r4, #1
	bne 	1b
	ldr 	r5, =FLASH_WORD_32
	STRH    r1, [r5, r3]        @ Store the 16-bit value to flash line buffer
	bx 		lr

@ r0 has the address to store to
@ r1 has the 16bit value to store
@ Note it should not cross the boundary as the 16 bits should be aligned
align_and_store_16bit:
    PUSH    {r4-r6, lr}         @ Save registers
								@ Align the buffer to the 32-byte boundary
	BIC     r2, r0, #31         @ r2 = base address of aligned buffer
								@ Compute the offset inside the buffer
	AND     r3, r0, #31         @ r3 = offset within the aligned buffer
	BL 		read_line
	BL 		flash_line
    POP     {r4-r6, pc}         @ Restore registers and return

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "hflash!" @ ( x Addr -- )
  @ Schreibt an die auf 2 gerade Adresse in den Flash.
h_flashkomma:
@ -----------------------------------------------------------------------------
  push {lr}
  popda r0 @ Adresse
  popda r1 @ Inhalt.
  @ Ist die gewünschte Stelle im Flash-Dictionary ? Außerhalb des Forth-Kerns ?
  @ Is the desired location in the Flash Dictionary? Outside the Forth core
  ldr r3, =Kernschutzadresse
  cmp r0, r3
  blo 3f

  ldr r3, =FlashDictionaryEnde
  cmp r0, r3
  bhs 3f


  @ Prüfe Inhalt. Schreibe nur, wenn es NICHT -1 ist. Check content. Write only if it is NOT -1.
  ldr r3, =0xFFFF
  ands r1, r3  @ High-Halfword der Daten wegmaskieren
  cmp r1, r3
  beq 2f @ Fertig ohne zu Schreiben Done without writing

  @ Prüfe die Adresse: Sie muss auf 2 gerade sein: Check the address: It must be even on 2:
  ands r2, r0, #1
  cmp r2, #0
  bne 3f

.ifndef flashOverwrite 
  @ is there 0xffff at programming location ?
  ldrh r2, [r0]
  cmp r2, r3
  bne 3f
.else  
  @ Is place overwritable ?
  ldrh r2, [r0]
  and r2, r1
  cmp r2, r1
  bne 3f
.endif
  
  @ Okay, all tests passed. 

  @ In STM32H7 flash-memory write location is at 0x0800 0000
  @ so we relocate write request to that area
  bics r0, #0xff000000
  bics r0, #0x00F00000
  adds r0, #0x08000000

  @ ready for writing !

  @ align on 256bit/32byte boundary
  @ read into this 32byte buffer what is already there
  @ copy the 16bits into the 32byte buffer
  @ then finally write the flash word (32bytes) to flash
  bl align_and_store_16bit

2: 	pop {pc}

3: 	pop {lr}
	Fehler_Quit "Wrong address or data for writing flash !"


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "cflash!" @ ( x Addr -- )
  @ Schreibt ein einzelnes Byte in den Flash.
c_flashkomma:
@ -----------------------------------------------------------------------------
  popda r0 @ Adresse
  popda r1 @ Inhalt.

  @ Ist die gewünschte Stelle im Flash-Dictionary ? Außerhalb des Forth-Kerns ?
  ldr r3, =Kernschutzadresse
  cmp r0, r3
  blo 3b

  ldr r3, =FlashDictionaryEnde
  cmp r0, r3
  bhs 3b


  @ Prüfe Inhalt. Schreibe nur, wenn es NICHT -1 ist.
  ands r1, #0xFF @ Alles Unwichtige von den Daten wegmaskieren
  cmp  r1, #0xFF
  beq 2f @ Fertig ohne zu Schreiben

  @ Ist an der gewünschten Stelle -1 im Speicher ?
  ldrb r2, [r0]
  cmp r2, #0xFF
  bne 3b

  @ Okay, alle Proben bestanden. 

  @ Im STM32F4 ist der Flash-Speicher gespiegelt, die wirkliche Adresse liegt weiter hinten !
  bics r0, #0xFF000000
  bics r0, #0x00F00000
  adds r0, #0x08000000

  @ Bereit zum Schreiben !

  @ Unlock Flash Control
  ldr r2, =FLASH_KEYR
  ldr r3, =0x45670123
  str r3, [r2]
  ldr r3, =0xCDEF89AB
  str r3, [r2]

  @ Set size to write
  ldr r2, =FLASH_CR
  ldr r3, =0x00000002 @ 8 Bits programming
  str r3, [r2]

  @ Write to Flash !
  dsb
  strb r1, [r0]
  dsb

  @ Wait for Flash BUSY Flag to be cleared
  ldr r2, =FLASH_SR

1:  ldr r3, [r2]
    ands r3, #0x00010000
    bne 1b

  @ Lock Flash after finishing this
  ldr r2, =FLASH_CR
  ldr r3, =0x00000001
  str r3, [r2]

2:bx lr

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "eraseflashsector" @ ( u -- )
eraseflashsector:  @ Löscht einen Flash-Sektor
@ -----------------------------------------------------------------------------
  push {lr}

  cmp tos, #1   @ Nicht den Kern in Sektor 0 löschen
  blo 2f
  cmp tos, #8   @ Es gibt nur 8 Sektoren
  bhs 2f

  ldr r2, =FLASH_KEYR
  ldr r3, =0x45670123
  str r3, [r2]
  ldr r3, =0xCDEF89AB
  str r3, [r2]

  write "Erase sector "
  dup
  bl udot

  @ Set sector to erase
  ldr r2, =FLASH_CR
  ldr r3, =0x00000084
  lsls tos, #3
  orrs r3, tos
  str r3, [r2]

    @ Wait for Flash BUSY Flag to be cleared
    ldr r2, =FLASH_SR
1:  ldr r3, [r2]
    ands r3, #0x00010000
    bne 1b

  @ Lock Flash after finishing this
  ldr r2, =FLASH_CR
  ldr r3, =0x00000001
  str r3, [r2]

  writeln "from Flash."

2:drop
  pop {pc}


.macro loeschpruefung Anfang Ende Sektornummer
  ldr r0, =\Anfang
  ldr r1, =\Ende
1:ldr r2, [r0]
  cmp r2, #0xFFFFFFFF
  beq 2f
    pushdaconst \Sektornummer
    bl eraseflashsector
    b 3f
2:adds r0, #4
  cmp r0, r1
  blo 1b
3:@ Diesen Sektor fertig durchkämmt
.endm

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "eraseflash" @ ( -- )
  @ Löscht den gesamten Inhalt des Flashdictionaries.
@ -----------------------------------------------------------------------------
  @ Flash ist in Sektoren aufgeteilt. Prüfe die nacheinander, ob ein Löschen nötig ist.
  @ So kann ich den Speicher schonen und flott löschen :-)
  cpsid i @ Interrupt-Handler deaktivieren

  push {lr}

@ -----------------------------------------------------------------------------
@ 32 kb sectors
@ loeschpruefung  0x08000000  0x08007FFF  0
  loeschpruefung  0x08008000  0x0800FFFF  1
  loeschpruefung  0x08010000  0x08017FFF  2
  loeschpruefung  0x08018000  0x0801FFFF  3

@ -----------------------------------------------------------------------------
@ 128 kb sector
  loeschpruefung  0x08020000  0x0803FFFF  4

@ -----------------------------------------------------------------------------
@ 256 kb sectors
  loeschpruefung  0x08040000  0x0807FFFF  5
  loeschpruefung  0x08080000  0x080BFFFF  6
  loeschpruefung  0x080C0000  0x080FFFFF  7

  writeln "Finished. Reset !"

  pop {lr}

  b Restart
