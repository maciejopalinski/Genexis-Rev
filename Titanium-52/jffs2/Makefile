JEFFERSON := ../.venv/bin/jefferson

all: extracted

extracted: jffs2.img $(JEFFERSON)
	$(JEFFERSON) -d $@ $<
	find $@ -type f -exec shasum {} \;

clean:
	rm -rf extracted/