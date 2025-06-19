drgldr-hrg1000-1.3.1-RC14.bin: bootloader.img
	binwalk -qe $<
	mv extractions/bootloader.img.extracted/0/drgldr-hrg1000-1.3.1-RC14.bin $@
	rm -rf extractions/
	file $@
	binwalk $@

clean:
	rm -vr drgldr-hrg1000-1.3.1-RC14.bin