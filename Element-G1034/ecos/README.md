# eCos

## u-Boot kernel images

Flash_OS1.bin and Flash_OS2.bin are partition images. These partitions contain u-Boot images that are used to boot the eCos operating system on the target hardware.

The first 64 bytes of the images contain the u-Boot header, which is used by u-Boot to identify the image and its properties.

The next 342111 bytes contain the eCos kernel image itself, which is loaded into memory by u-Boot.

The extracted u-Boot images are the same in both Flash_OS1.bin and Flash_OS2.bin, but the additional data is different.

```sh
shasum Flash_OS*.Image
aca31deeb0bb01e564ae67ca3fe0165359ffa8ce  Flash_OS1.Image
aca31deeb0bb01e564ae67ca3fe0165359ffa8ce  Flash_OS2.Image
```

The rest of the image is not padding, but rather some additional data. It is still not clear what this additional data is used for, but it may contain configuration or metadata related to the eCos kernel or the target hardware.

```sh
shasum Flash_OS*.rest.bin
b82a15f97b707bb0b0212d713ed7275657726afa  Flash_OS1.rest.bin
f0beaec2c2dd3ed526a40dde30af6c3c38ed0444  Flash_OS2.rest.bin
```

## Additional Binary Data

The files are the same for the first 0x0002c750 bytes. After that, the files diverge.

```
0002c6e0: 1024 1300 7d24 1200 8002 8038 2100 0080  .$..}$....   0002c6e0: 1024 1300 7d24 1200 8002 8038 2100 0080  .$..}$....
0002c6f0: 2108 03bf ea00 0010 2126 1000 0124 e700  !.......!&   0002c6f0: 2108 03bf ea00 0010 2126 1000 0124 e700  !.......!&
0002c700: 0112 1200 0f02 0010 2100 4610 2b10 4000  ........!.   0002c700: 0112 1200 0f02 0010 2100 4610 2b10 4000  ........!.
0002c710: 0c8f a400 0480 8300 0024 8200 01af a200  .........$   0002c710: 0c8f a400 0480 8300 0024 8200 01af a200  .........$
0002c720: 0414 73ff f5a0 e300 0090 8200 0124 8300  ..s.......   0002c720: 0414 73ff f5a0 e300 0090 8200 0124 8300  ..s.......
0002c730: 0234 4200 20a0 e200 0008 03bf e6af a300  .4B. .....   0002c730: 0234 4200 20a0 e200 0008 03bf e6af a300  .4B. .....
0002c740: 0402 8020 210c 03c4 2102 0030 2114 5000  ... !...!.   0002c740: 0402 8020 210c 03c4 2102 0030 2114 5000  ... !...!.
0002c750: 328f a500 008f a200 0c00 b028 2100 5010  2.........   0002c750: 328f a500 008f a200 0c00 b028 2100 5010  2.........
0002c760: 23ff ffff ffff ffff ffff ffff ffff ffff  #......... | 0002c760: 2300 a6e7 dbff ff30 303a 3030 3a30 303a  #......00:
0002c770: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c770: 3030 3a30 303a 3030 0030 303a 6262 3a62  00:00:00.0
0002c780: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c780: 623a 6565 3a65 653a 3232 0030 303a 3030  b:ee:ee:22
0002c790: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c790: 3a30 303a 3030 3a30 303a 3030 0030 303a  :00:00:00:
0002c7a0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7a0: 3030 3a30 303a 3030 3a30 303a 3030 0030  00:00:00:0
0002c7b0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7b0: 303a 3030 3a30 303a 3030 3a30 303a 3030  0:00:00:00
0002c7c0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7c0: 004e 7b7c 79cf 72ed fa83 1fc6 5f22 49be  .N{|y.r...
0002c7d0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7d0: 1a52 9ab6 4a44 1f72 407f edad 3b99 fdec  .R..JD.r@.
0002c7e0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7e0: ab74 933f 25ee 91e7 3a98 d0c9 fb18 d3a0  .t.?%...:.
0002c7f0: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c7f0: 7a6f 8acf 566a e792 4294 3b09 683b 49f3  zo..Vj..B.
0002c800: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c800: 73aa d5a0 dc68 55cf 1597 4ded 034a 4b44  s....hU...
0002c810: ffff ffff ffff ffff ffff ffff ffff ffff  .......... | 0002c810: 1020 5030 4a5e 47b6 cdfc 0af4 cbb8 13b2  . P0J^G...
```
