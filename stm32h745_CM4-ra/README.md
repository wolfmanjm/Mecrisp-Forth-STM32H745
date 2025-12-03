This folder has a version of mecrisp for the STM32H745 running on the M4 core.
It does require a C stub running on the M7 core that does the SWD comms protocal and realys to the UART.

The CM4 core runs from Flash page 2 at 0x081C0000. It uses SRAM4 at 0x38000000
with RAM usage at 0x38000800 and the SWDCOMMS buffer at 0x38000000 and flash
buffer at 0x38000400

The plan for Smoothieboard V2 is to have the kernel in Flash, but the saved
user dictionary (compiletoflash) in the QSPI Flash, this can either be used
directly or can be copied to RAM on boot (for speed and ease). It is possible
that with the mapped QSPI we could have the kernel in QSPI Flash as well, if
the core CM4 can boot from the mapped QSPI.

On the Nucleo board that does not have QSPI flash we could store the user
dictionary in Flash.
