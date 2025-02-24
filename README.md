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



