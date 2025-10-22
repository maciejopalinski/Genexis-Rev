all: Flash_OS1.Image Flash_OS1.rest.bin Flash_OS2.rest.bin

Flash_OS%.Image: Flash_OS%.Image.lzma
	lzma -dc "$<" > "$@"

Flash_OS%.Image.lzma: Flash_OS%.uImage
	dumpimage -l "$<"
	dumpimage -T kernel -o "$@" "$<"

Flash_OS%.uImage Flash_OS%.rest.bin: ../fis/bin/Flash_OS%.bin
	dd if="$<" of="$@" bs=342175 count=1
	dd if="$<" of="Flash_OS$*.rest.bin" bs=1 skip=342175

clean:
	rm -f *.uImage *.zImage *.Image *.bin