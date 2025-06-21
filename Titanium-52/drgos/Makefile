all: drgos-hrg1000-1.6.5-R.initrd

%.initrd: %.initrd.cpio
	mkdir -p $@
	cpio -idmvD $@ --no-absolute-filenames < $<

%.initrd.cpio: %.initrd.cpio.gz
	gunzip -k $<

%.initrd.cpio.gz: %.Image
	dd if=$< of=$@ bs=1 skip=110592 count=9244289

%.Image: %.zImage
	gunzip -k < $< > $@

%.zImage: ../jffs2/extracted/00/%.img
	dd if=$< of=$@ bs=64 skip=1

clean:
	rm -rf drgos* initrd*