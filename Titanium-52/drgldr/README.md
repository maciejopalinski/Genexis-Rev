# drgldr

drgldr-hrg1000-1.3.1-RC14

second stage bootloader, based on U-boot

## Boot process

-   reads the mtd1 partition
-   scans the JFFS2 filesystem contained on it
-   loads the u-boot image
-   boots the kernel
