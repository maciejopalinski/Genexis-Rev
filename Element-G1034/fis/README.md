# FLASH Image System (FIS)

FIS is a file system designed for embedded systems, providing a way to manage files in flash memory. It is particularly useful for devices with limited resources, allowing for efficient storage and retrieval of files.

## Partitions

```sh
RedBoot> fis list
Name              FLASH addr  Mem addr    Length      Entry point
RedBoot           0xBFC00000  0xBFC00000  0x00030000  0x00000000
FIS directory     0xBFC30000  0xBFC30000  0x00000100  0x00000000
RedBoot config    0xBFC30100  0xBFC30100  0x0000FF00  0x00000000
Flash_OS1         0xBFC50000  0x80010000  0x000D0000  0x800100BC
Flash_OS2         0xBFD20000  0x80010000  0x000D0000  0x800100BC
```

## Dump

The flash memory can be dumped using the `dump` command in RedBoot. After dumping, the data can be converted to a binary file using the `hexdump_to_bin.py` script.
