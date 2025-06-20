JEFFERSON := ../.venv/bin/jefferson

extracted: JFFS2.img $(JEFFERSON)
	$(JEFFERSON) -d $@ $<
	find $@ -type f -exec shasum {} \;

JFFS2.img: ../mtd/mtdblock1
	ln -vsf $< $@

clean:
	rm -rf JFFS2.img extracted