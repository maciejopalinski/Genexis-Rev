JEFFERSON := ../.venv/bin/jefferson

extracted: ../mtd/JFFS2.img $(JEFFERSON)
	$(JEFFERSON) -d $@ $<
	find $@ -type f -exec shasum {} \;

clean:
	rm -rf JFFS2.img extracted