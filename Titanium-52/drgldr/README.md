# drgldr

drgldr-hrg1000-1.3.1-RC14

second stage bootloader, based on U-boot

## Boot process

-   reads the mtd1 partition
-   scans the JFFS2 filesystem contained on it
-   loads the u-boot image
-   boots the kernel

## Example commands

### Booting from file

```
fsload 0x84800000 /00/drgos-hrg1000-1.6.5-R.img
setenv bootargs ${bootargs} loglevel=7
bootm 0x84800000
```

### Booting from tftp

```
tftp 0x84800000 drgos-hrg1000-1.6.5-R.img
setenv bootargs ${bootargs} loglevel=7
bootm 0x84800000
```

## Calculate CRC32 of every partition

```
hrg1000 > crc32 20000000 20000
CRC32 for 20000000 ... 2001ffff ==> 1457a30a
hrg1000 > crc32 0x20020000 0x1e80000
CRC32 for 20020000 ... 21e9ffff ==> c7379fb3
hrg1000 > crc32 0x21ea0000 0x80000
CRC32 for 21ea0000 ... 21f1ffff ==> 3f5d8bed
hrg1000 > crc32 0x21f20000 0x80000
CRC32 for 21f20000 ... 21f9ffff ==> 3f5d8bed
hrg1000 > crc32 0x21fa0000 0x20000
CRC32 for 21fa0000 ... 21fbffff ==> d7171eb7
hrg1000 > crc32 0x21fc0000 0x20000
CRC32 for 21fc0000 ... 21fdffff ==> ae5e9c44
hrg1000 > crc32 0x21fe0000 0x20000
CRC32 for 21fe0000 ... 21ffffff ==> 154803cc
```

## Flash partition

```
tftp 81000000 JFFS2.img
protect off all
dcache off
erase 0x20020000 +0x1e80000
cp.b 0x81000000 0x20020000 0x1e80000
crc32 0x81000000 0x1e80000
crc32 0x20020000 0x1e80000
```

This downloads a JFFS2 image via TFTP to RAM at address 0x81000000, erases the JFFS2 partition on flash, copies the image from RAM to flash, and verifies the CRC32 checksum.
