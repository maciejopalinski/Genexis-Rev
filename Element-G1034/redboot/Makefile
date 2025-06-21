all: RedBoot.bin RedBoot\ config.bin

RedBoot.bin: ../fis/bin/RedBoot.bin
	ln -vsf "$<" "$@"

RedBoot\ config.bin: ../fis/bin/RedBoot\ config.bin
	ln -vsf "$<" "$@"

clean:
	rm -f RedBoot.bin RedBoot\ config.bin