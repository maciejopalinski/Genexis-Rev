drgboot-hrg1000-1.3.1-RC12.bin: Bootstrap.img
	dd if=$< of=$@ bs=1 count=70058
	# rest is padded with ffff

Bootstrap.img: ../mtd/mtdblock0
	ln -vsf $< $@

clean:
	rm -rf Bootstrap.img drgboot*