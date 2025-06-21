all: RedBoot.bin RedBoot\ config.bin

%.bin: ../fis/bin/%.bin
	ln -vsf "$<" "$@"

clean:
	rm -f RedBoot.bin RedBoot\ config.bin