all: drgboot-hrg1000-1.3.1-RC12.bin

drgboot-hrg1000-1.3.1-RC12.bin: ../mtd/Bootstrap.img
	dd if=$< of=$@ bs=1 count=70058
	# rest is padded with ffff

clean:
	rm -rf drgboot*