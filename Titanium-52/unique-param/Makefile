unique-param.txt: UniqueParam.img
	dd if=$< of=$@ bs=1 count=2252

UniqueParam.img: ../mtd/mtdblock4
	ln -vsf $< $@

clean:
	rm -rf UniqueParam.img unique-param.txt