This a a copy of the mecrisp-stellaris source directory.

The changes I have made are as follows....

* added stm32h745 port
* fixed a bug in create when 32byte aligned flash is needed

I have ported some core code to allow for the 32bit flash alignment, the files changed in ./common are:

* boot.s
* flash32bytesblockwrite.s
* forth-core.s
* datastackandmacros.s
* codegenerator-m0.s
* compiler-flash.s
* codegenerator-m3.s


I fixed a bug in create that left an address 16 bytes short when the new word is called. The fix is in:

* codegenerator-m3.s Line 524

Also...

* added a version of crests stm32h750 port modified for the weact h750 board
* added the missing ACK/NAK codes to colored prompts
* added swdcomm support to the STM32H745 port, and uses swd as the default as it is a Nucleo board
  but a define in mecrisp-stellaris-stm32h745.s can switch back to the uart as default


See https://github.com/wolfmanjm/forth4stm32h745 for forth source code to run on these platforms
