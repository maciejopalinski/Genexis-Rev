# Titanium-52 MTD Partitioning

## Partitions

### Bootstrap (mtd0)

The bootstrap partition is a 128 KiB partition that contains the first stage bootloader. It is responsible for loading the second stage bootloader (drgldr) from the mtd2 or mtd3 partition.

### JFFS2 (mtd1)

The JFFS2 partition is a 30.5 MiB partition that contains a JFFS2 filesystem. The filesystem contains configuration and two u-boot images of drgos operating system. It is scanned by the second stage bootloader (drgldr) to load the u-boot image and boot the system.

### Bootloader1 (mtd2) and Bootloader2 (mtd3)

The Bootloader1 and Bootloader2 partitions are 512 KiB partitions that contain the second stage bootloader (drgldr). The second stage bootloader is responsible for reading the JFFS2 partition, scanning the filesystem, loading the u-boot image, and booting the kernel.

Bootloader2 partition is a backup of Bootloader1 partition. It is used in case the Bootloader1 partition is corrupted or not present.

### UniqueParam (mtd4)

The UniqueParam partition is a 128 KiB partition that contains unique parameters for the device. It contains the device's serial number, MAC address, dropbear ssh host keys, and other unique identifiers. It has not been yet identified during what part of the boot process it is used.

### BootloaderCFG (mtd5)

The BootloaderCFG partition is a 128 KiB partition that contains configuration data for the second stage bootloader. It is used to store env variables and other configuration settings for the bootloader. You can print the variables using the `printenv` command in the u-boot console, modify the variables using the `setenv` command, and save the changes using the `saveenv` command.

### SharedCFG (mtd6)

The SharedCFG partition is a 128 KiB partition that does not contain any useful data. It is an empty partition filled with ffff.

## MTD Device Information

```sh
cat /proc/mtd

dev: size erasesize name
mtd0: 00020000 00020000 "Bootstrap"
mtd1: 01e80000 00020000 "JFFS2"
mtd2: 00080000 00020000 "Bootloader1"
mtd3: 00080000 00020000 "Bootloader2"
mtd4: 00020000 00020000 "UniqueParam"
mtd5: 00020000 00020000 "BootloaderCFG"
mtd6: 00020000 00020000 "SharedCFG"
```

```sh
file mtdblock*

mtdblock0: data
mtdblock1: Linux jffs2 filesystem data little endian
mtdblock2: u-boot legacy uImage, drgldr-hrg1000-1.3.1-RC14, Linux/ARM, Standalone Program (Not compressed), 245080 bytes, Wed Jun 27 15:05:16 2012, Load Address: 0X87000000, Entry Point: 0X87000000, Header CRC: 0XC272D181, Data CRC: 0XF613D197
mtdblock3: u-boot legacy uImage, drgldr-hrg1000-1.3.1-RC14, Linux/ARM, Standalone Program (Not compressed), 245080 bytes, Wed Jun 27 15:05:16 2012, Load Address: 0X87000000, Entry Point: 0X87000000, Header CRC: 0XC272D181, Data CRC: 0XF613D197
mtdblock4: ISO-8859 text, with very long lines (63284)
mtdblock5: data
mtdblock6: ISO-8859 text, with very long lines (65536), with no line terminators
```

## Memory Map

```sh
                    Flash:          0x20000000 - 0x21ffffff     size 0x2000000      (32     MiB)
                    RAM:            0x80000000 - 0x87ffffff     size 0x8000000      (128    MiB)

/dev/mtdblock0      Bootstrap:      0x20000000 - 0x2001ffff     size 0x20000        (128    KiB)
/dev/mtdblock1      JFFS2:          0x20020000 - 0x2203ffff     size 0x1e80000      (30.5   MiB)
/dev/mtdblock2      Bootloader1:    0x21ea0000 - 0x21f1ffff     size 0x80000        (512    KiB)
/dev/mtdblock3      Bootloader2:    0x21f20000 - 0x21f9ffff     size 0x80000        (512    KiB)
/dev/mtdblock4      UniqueParam:    0x21fa0000 - 0x21fbffff     size 0x20000        (128    KiB)
/dev/mtdblock5      BootloaderCFG:  0x21fc0000 - 0x21fdffff     size 0x20000        (128    KiB)
/dev/mtdblock6      SharedCFG:      0x21fe0000 - 0x21ffffff     size 0x20000        (128    KiB)
```
