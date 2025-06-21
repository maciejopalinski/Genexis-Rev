all: Flash_OS1.Image Flash_OS1.rest.bin Flash_OS2.rest.bin

Flash_OS%.Image: Flash_OS%.zImage
	lzma -dc $< > $@

Flash_OS%.zImage: Flash_OS%.uImage
	dd if=$< of=$@ bs=1 skip=64

Flash_OS%.uImage Flash_OS%.rest.bin: Flash_OS%.bin
	dd if=$< of=$@ bs=1 count=342175
	dd if=$< of=Flash_OS$*.rest.bin bs=1 skip=342175

%.bin: ../fis/bin/%.bin
	ln -vsf "$<" "$@"

clean:
	rm -f *.uImage *.zImage *.Image *.bin