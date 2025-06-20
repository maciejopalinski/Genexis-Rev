drgldr-hrg1000-1.3.1-RC14.bin: drgldr-hrg1000-1.3.1-RC14.uImage
	dd if=$< of=$@ bs=64 skip=1

drgldr-hrg1000-1.3.1-RC14.uImage: Bootloader1.img
	dd if=$< of=$@ bs=1 count=245144
	# rest is padded with ffff

Bootloader1.img: ../mtd/mtdblock2
	ln -vsf $< $@

Bootloader2.img: ../mtd/mtdblock3
	ln -vsf $< $@

clean:
	rm -vrf drgldr* Bootloader*