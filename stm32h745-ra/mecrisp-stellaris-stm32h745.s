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

.syntax unified
.cpu cortex-m7
.thumb

@ -----------------------------------------------------------------------------
@ Swiches for capabilities of this chip
@ -----------------------------------------------------------------------------

.equ registerallocator, 1
@.equ charkommaavailable, 1
.equ does_above_64kb, 1
.equ flash32bytesblockwrite, 1
.equ color, 1

@ set the default comms to use
.equ default_swdcomms, 1

@ -----------------------------------------------------------------------------
@ Start with some essential macro definitions
@ -----------------------------------------------------------------------------

.include "../common/datastackandmacros.s"

@ -----------------------------------------------------------------------------
@ Speicherkarte für Flash und RAM
@ Memory map for Flash and RAM
@ -----------------------------------------------------------------------------

@ Konstanten für die Größe des Ram-Speichers
@ constants for the size of the RAM memory
.equ RamAnfang, 0x24000000 @ Start of RAM_D1 (AXI SRAM) Porting: Change this !
.equ RamEnde,   0x24080000 @ End   of RAM. 512 kb. Porting: Change this !

@ Konstanten für die Größe und Aufteilung des Flash-Speichers
@ Constants for the size and distribution of the flash memory
.equ Kernschutzadresse,     0x08020000 @ Darunter wird niemals etwas geschrieben ! Mecrisp core never writes flash below this address.
@ Note that the H743/5 can only erase flash in 128K sectors, this is why we have so much
.equ FlashDictionaryAnfang, 0x08020000 @ 128  kb für den Kern reserviert. 128kb Flash reserved for core.
.equ FlashDictionaryEnde,   0x08100000 @ 896kb Platz für das Flash-Dictionary 896kb Flash available. Porting: Change this !
.equ Backlinkgrenze,        RamAnfang  @ Ab dem Ram-Start.


@ -----------------------------------------------------------------------------
@ Anfang im Flash - Interruptvektortabelle ganz zu Beginn
@ Flash start - Vector table has to be placed here
@ -----------------------------------------------------------------------------
.text    @ Hier beginnt das Vergnügen mit der Stackadresse und der Einsprungadresse
.include "vectors.s" @ You have to change vectors for Porting !

@ -----------------------------------------------------------------------------
@ Include the Forth core of Mecrisp-Stellaris
@ -----------------------------------------------------------------------------

.include "../common/forth-core.s"

@ -----------------------------------------------------------------------------
Reset: @ Einsprung zu Beginn
@ -----------------------------------------------------------------------------
   @ Initialisierungen der Hardware, habe und brauche noch keinen Datenstack dafür
   @ Initialisations for Terminal hardware, without Datastack.
   bl uart_init

   @ Catch the pointers for Flash dictionary
   .include "../common/catchflashpointers.s"

   welcome " for STM32H745 Nucleo v3 by Matthias Koch"

   @ Ready to fly !
   .include "../common/boot.s"
