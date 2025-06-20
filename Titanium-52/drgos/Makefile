all: extract

extract: initrd

initrd: initrd.cpio
	mkdir -p initrd
	cpio -idmvD initrd --no-absolute-filenames < $<

initrd.cpio: initrd.cpio.gz
	gunzip -k $<

initrd.cpio.gz: drgos-hrg1000-1.6.5-R.Image
	dd if=$< of=$@ bs=1 skip=110592 count=9244289

drgos-hrg1000-1.6.5-R.Image: drgos-hrg1000-1.6.5-R.Image.gz
	gunzip -k $<

drgos-hrg1000-1.6.5-R.Image.gz: drgos-hrg1000-1.6.5-R.uImage
	dd if=$< of=$@ bs=64 skip=1

drgos-hrg1000-1.6.5-R.uImage: ../jffs2/extracted/00/drgos-hrg1000-1.6.5-R.img
	ln -vsf $< $@

clean:
	rm -rf drgos* initrd*