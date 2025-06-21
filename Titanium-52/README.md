# Genexis Hybrid Live! Titanium-52

[Manufacturer Datasheet](./datasheets/Hybrid-Live-Titanium-RG-Datasheet-v5.0-EN.pdf)

## Hardware

-   [Mindspeed J83100G PFX562.00C M83241G-13 - Comcerto 1000, ARM1136 Core Communication Processor]()
-   [Atheros AR8328-BK1A - 7-port Low-power Managed/Layer3 Gigabit Switch with Hardware NAT](./datasheets/qualcomm_ethos-ar8328-ar8328n.pdf)
-   [Si32260-FW - Single-Chip Dual ProSlic](./datasheets/Si32260-61.pdf)
-   [2x Nanya NT5TU32M16DG-AC - DDR2 512Mb SDRAM](./datasheets/512Mb_DDR2_F_Die_component_Datasheet.pdf)
-   [MXIC MX29GL256FHT2I-90Q - Single Voltage 3V Only Flash Memory](./datasheets/MX29GL256F,%203V,%20256Mb,%20v1.5.pdf)
-   [TPS54427 - 4.5V to 18V Input, 4A Synchronous Step-Down Converter](./datasheets/tps54427.pdf)
-   [TPS54227 - 4.5V to 18V input, 2A synchronous step-down converter in HSOP and VSON package](./datasheets/tps54227.pdf)
-   [2x LM339A](./datasheets/lm339a.pdf)
-   [AP7165 - 600mA LOW DROPOUT REGULATOR WITH POK](./datasheets/AP7165.pdf)

## Boot Process

-   The device boots the first stage bootloader, which is stored in the mtd0 partition.
-   The first stage bootloader loads the second stage bootloader (drgldr) from the mtd2 partition or mtd3 backup partition.
-   The second stage bootloader reads the mtd1 partition, scans the JFFS2 filesystem contained on it, loads the u-boot image, and boots the kernel.
