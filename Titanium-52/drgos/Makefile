all: extract

extract: initrd

initrd: initrd.cpio
	mkdir -p initrd
	cpio -idmvD initrd --no-absolute-filenames < $<

initrd.cpio: drgos-hrg1000-1.6.5-R.img
	binwalk -qe $< -y gzip
	mv extractions/drgos-hrg1000-1.6.5-R.img.extracted/*/decompressed.bin $@
	rm -rf extractions/
	file $@
	binwalk $@

drgos-hrg1000-1.6.5-R.img: drgos-hrg1000-1.6.5-R.gzip
	gunzip -c $< > $@
	file $@
	binwalk $@

drgos-hrg1000-1.6.5-R.gzip: drgos-hrg1000-1.6.5-R.uImage
	binwalk -qe $<
	mv extractions/drgos-hrg1000-1.6.5-R.uImage.extracted/0/drgos-hrg1000-1.6.5-R.bin $@
	rm -rf extractions/
	file $@
	binwalk $@

drgos-hrg1000-1.6.5-R.uImage: ../jffs2/extracted/00/drgos-hrg1000-1.6.5-R.img
	ln -vsf $< $@
	file -L $@
	mkimage -l $@
	binwalk $@

clean:
	rm -vr drgos-hrg1000-1.6.5-R.uImage drgos-hrg1000-1.6.5-R.gzip drgos-hrg1000-1.6.5-R.img initrd.cpio initrd