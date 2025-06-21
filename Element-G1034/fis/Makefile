all: bin/RedBoot.bin bin/FIS\ directory.bin bin/RedBoot\ config.bin bin/Flash_OS1.bin bin/Flash_OS2.bin

bin/%.bin: hex/%.hex bin
	base_hex=$$(head -n1 "$<" | cut -d: -f1); \
	base_dec=$$((0x$${base_hex})); \
	cat "$<" | sed 's/ \+/ /g' | xxd -r -s -$${base_dec} > "$@"

bin:
	mkdir -p bin

clean:
	rm -rf bin