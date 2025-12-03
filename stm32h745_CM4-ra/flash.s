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

@ Schreiben und Löschen des Flash-Speichers im STM32H745.
  @ Writing and erasing the flash memory in the STM32H745.

@ In diesem Chip gibt es Flashschreibzugriffe mit wählbarer Breite -
@ so ist es diesmal ganz komfortabel. Leider gibt es nur weniger große
@ Sektoren, die getrennt gelöscht werden können.
  @ This chip has selectable-width flash write accesses -
  @ so it's quite convenient this time. Unfortunately, there are only a few large
  @ sectors that can be erased separately.

@ Write and Erase Flash in STM32H745.
@ NOTE this only supports writing to the second 1MB flash bank2

@ Porting: Rewrite this ! You need hflash! and - as far as possible - cflash!

.equ FLASH_Base, 0x52002000

.equ FLASH_KEYR,    FLASH_Base + 0x104 @ Flash Key Register
.equ FLASH_CR,      FLASH_Base + 0x10C @ Flash Control Register
.equ FLASH_SR,      FLASH_Base + 0x110 @ Flash Status Register
.equ FLASH_CCR,     FLASH_Base + 0x114 @ Flash Clear Control Register

@ put the 32byte flash buffer in...
.equ FLASH_BUFFER, 0x38000400  @ SRAM4 above swdcomms buffer

.equ FLASH_ERROR_MSK, 0x00020000|0x00040000|0x00080000|0x00400000|0x00800000|0x01000000|0x04000000|0x00200000|0x02000000

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

@ flash the 32 byte flash line to flash at
@ address in r0
@ from buffer in r1
flash_line:
	push    {r0-r4, lr}
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
 	ldr   	r2, =FLASH_CR
	ldr   	r4, [r2]
  	orr   	r4, #0x00000002
	str   	r4, [r2]

	ISB
	DSB

	@ Write to Flash from the flash line buffer 32 bytes in r1
	mov 	r2, r1
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
	pop     {r0-r4, pc}

3: 	Fehler_Quit "Error 1 writing flash !"

4: 	pushdatos			@ print out the error code we got
  	mov 	tos, r4
  	bl 		hexdot
	Fehler_Quit "Error 2 writing flash !"

hexflashstore_fehler:
	Fehler_Quit "Flash cannot be written twice"

@ -----------------------------------------------------------------------------
Wortbirne Flag_visible, "32flash!" @ Writes 32 Bytes at once into Flash.
flashstore_32b: @ ( x1 x2 x3 x4 x5 x6 x7 x8 addr -- ) x1 contains LSB of those 256 bits.
@ -----------------------------------------------------------------------------
	push    {r0-r3, lr}
	movs    r0, #31
	ands    r0, tos
	beq     1f
	Fehler_Quit "32flash! needs 32-aligned address"

	@ check first word to make sure it is virgin unprogrammed
1:	ldr 	r0, [tos]  @ tos contains address to write
	adds 	r0, #1    @ quick check if memory contains $ffffffff
	bne 	hexflashstore_fehler

	ldr 	r0, [tos, #4] @ check next 4 bytes at offset 4
	adds 	r0, #1
	bne 	hexflashstore_fehler

	movs	r0, tos                 // addr
	drop
	ldr     r1, =FLASH_BUFFER
	str     tos, [r1, #28]          // x8
	drop
	str     tos, [r1, #24]          // x7
	drop
	str     tos, [r1, #20]          // x6
	drop
	str     tos, [r1, #16]          // x5
	drop
	str     tos, [r1, #12]          // x4
	drop
	str     tos, [r1, #8]           // x3
	drop
	str     tos, [r1, #4]           // x2
	drop
	str     tos, [r1]               // x1
	drop
	bl      flash_line
	pop     {r0-r3, pc}

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

	@ HAL does this, checks for any last operation to finish without errors
	bl 		wait_for_last_operation
	cmp 	r2, #0
	beq		4f
	pushdatos			@ print out the error code we got
  	mov 	tos, r2
  	bl 		hexdot
	Fehler_Quit " Initial Flash error detected"

4:
	@ Set sector to erase
	ldr 	r2, =FLASH_CR
	ldr 	r3, [r2]
	and 	r3, #0x00000030|0x00000700
	orrs	r3, #0x00000004|0x00000030|0x00000080
	lsls 	tos, #8
	orrs 	r3, tos
	str 	r3, [r2]

	bl 		wait_for_last_operation
	mov  	r4, r2	 @ save any error

	@ Lock Flash after finishing this
	ldr 	r2, =FLASH_CR
	ldr		r3, [r2]
	ldr		r1, =0x00000004|0x00000700
	and 	r3, r1
	str 	r3, [r2]
	orrs	r3, #0x00000001
	str 	r3, [r2]

	@ check for error
	cmp 	r4, #0
	beq		5f
	pushdatos			@ print out the error code we got
  	mov 	tos, r4
  	bl 		hexdot
	Fehler_Quit " Flash erase error"

5:	writeln "from Flash."

2:	drop
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
  @ Deletes the entire contents of the Flash dictionary.
@ -----------------------------------------------------------------------------
  @ Flash ist in Sektoren aufgeteilt. Prüfe die nacheinander, ob ein Löschen nötig ist.
  @ So kann ich den Speicher schonen und flott löschen :-)
  @ Flash is divided into sectors. Check each one to see if deletion is necessary.
  @ This way I can save memory and delete quickly :-)
  cpsid i @ Interrupt-Handler deaktivieren

  push {lr}

@ -----------------------------------------------------------------------------
@ 128 kb sectors, 2nd bank
  loeschpruefung  0x081E0000  0x081FFFFF  7

  writeln "Finished. Reset !"

  pop {lr}

  b Restart
