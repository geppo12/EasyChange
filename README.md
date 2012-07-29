EasyChange
==========
EasyChange is a simple tool that let be able, with an easy graphical interface, change text file or script like 
make files, xml, python files ecc.

The only requerement is that source file permits comments. For example we can decorate a makefile with 
an easyhange section

```makefile

#test for EasyChange
#@GM@ M,COMPILER,arm,arm=arm-elf-gcc,i386=i386-elf-gcc
#@GM@ M,LINKER,arm,arm=arm-elf-ld,i386=i386-elf-ld

#@GM@ CC=@%COMPILER@%
CC=arm-elf-gcc

#@GM@ LD=@%LINKER@%
LD=arm-elf-ld

```

For any question you can contact me: info@ing-monteleone.com