all: drgos-hrg1000-1.6.5-R.Image drgos-hrg1000-1.6.5-R.initrd

%.initrd: %.initrd.cpio
	mkdir -p "$@"
	cpio -idmvD "$@" --no-absolute-filenames < "$<"

%.initrd.cpio: %.initrd.cpio.gz
	gunzip -k < "$<" > "$@"

%.initrd.cpio.gz: %.Image
	dd if="$<" of="$@" bs=512 skip=216 count=18056

%.Image: %.gzImage
	gunzip -k < "$<" > "$@"

%.gzImage: %.uImage
	dumpimage -l "$<"
	dumpimage -T kernel -o "$@" "$<"

%.uImage: ../jffs2/extracted/00/%.img
	ln -vsf "$<" "$@"

clean:
	rm -rf drgos* initrd*