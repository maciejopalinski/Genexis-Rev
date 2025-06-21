# Genexis Hybrid Element-G1034

[Manufacturer Datasheet](./datasheets/Hybrid-Element-NT-G1000-Series-Datasheet-v5.0-EN.pdf)

## Hardware

-   [Qualcomm QCA8828-AL3B]()
-   [MX25L3206E - 32M-bit [x 1 / x 2] CMOS Serial Flash](./datasheets/MX25L3206E.pdf)
-   [AOZ1050PI - EZBuck™ 2 A Synchronous Buck Regulator](./datasheets/AOZ1050PI.pdf)
-   [SN74LVC126A - Quadruple Bus Buffer Gate With 3-State Outputs](./datasheets/sn74lvc126a.pdf)
-   [LM339A - Precision quad differential comparator](./datasheets/lm339a.pdf)
-   [KPT22 PAXP - ?]()

## Boot Process

-   The device boots the first stage bootloader (RedBoot)
-   The first stage bootloader loads an eCos based operating system from the FIS partition.
