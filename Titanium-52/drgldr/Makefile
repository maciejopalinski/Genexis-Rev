all: drgldr-hrg1000-1.3.1-RC14.1.Image drgldr.env

%.Image: %.uImage
	dumpimage -l "$<"
	dumpimage -T kernel -o "$@" "$<"

drgldr-hrg1000-1.3.1-RC14.%.uImage: ../mtd/Bootloader%.img
	dd if="$<" of="$@" bs=245144 count=1
	# rest is padded with ffff

drgldr.env: drgldr.cfg
	dd if="$<" bs=4 skip=1 | tr '\0' '\n' > "$@"

drgldr.cfg: ../mtd/BootloaderCFG.img
	dd if="$<" of="$@" bs=16384 count=1

clean:
	rm -vrf drgldr*