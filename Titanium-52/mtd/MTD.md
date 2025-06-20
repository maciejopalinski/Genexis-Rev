```sh
cat /proc/mtd
```

```plaintext
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
```

```plaintext
mtdblock0: data
mtdblock1: Linux jffs2 filesystem data little endian
mtdblock2: u-boot legacy uImage, drgldr-hrg1000-1.3.1-RC14, Linux/ARM, Standalone Program (Not compressed), 245080 bytes, Wed Jun 27 15:05:16 2012, Load Address: 0X87000000, Entry Point: 0X87000000, Header CRC: 0XC272D181, Data CRC: 0XF613D197
mtdblock3: u-boot legacy uImage, drgldr-hrg1000-1.3.1-RC14, Linux/ARM, Standalone Program (Not compressed), 245080 bytes, Wed Jun 27 15:05:16 2012, Load Address: 0X87000000, Entry Point: 0X87000000, Header CRC: 0XC272D181, Data CRC: 0XF613D197
mtdblock4: ISO-8859 text, with very long lines (63284)
mtdblock5: data
mtdblock6: ISO-8859 text, with very long lines (65536), with no line terminators
```

## Memory Map

```plaintext
/dev/mtd0           Flash:          0x20000000 - 0x21ffffff     size 0x2000000      (32     MiB)
/dev/mtdblock0      Bootstrap:      0x20000000 - 0x2001ffff     size 0x20000        (128    KiB)
/dev/mtdblock1      JFFS2:          0x20020000 - 0x2203ffff     size 0x1e80000      (30.5   MiB)
/dev/mtdblock2      Bootloader1:    0x21ea0000 - 0x21f1ffff     size 0x80000        (512    KiB)
/dev/mtdblock3      Bootloader2:    0x21f20000 - 0x21f9ffff     size 0x80000        (512    KiB)
/dev/mtdblock4      UniqueParam:    0x21fa0000 - 0x21fbffff     size 0x20000        (128    KiB)
/dev/mtdblock5      BootloaderCFG:  0x21fc0000 - 0x21fdffff     size 0x20000        (128    KiB)
/dev/mtdblock6      SharedCFG:      0x21fe0000 - 0x21ffffff     size 0x20000        (128    KiB)
                    RAM:            0x80000000 - 0x87ffffff     size 0x8000000      (128    MiB)
```
