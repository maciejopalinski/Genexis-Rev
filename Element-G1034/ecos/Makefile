all: Flash_OS1.bin Flash_OS2.bin

%.bin: ../fis/bin/%.bin
	ln -vsf "$<" "$@"

clean:
	rm -f Flash_OS1.bin Flash_OS2.bin