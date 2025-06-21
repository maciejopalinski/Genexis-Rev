SUBDIRS := ecos fis redboot

.PHONY: all clean $(SUBDIRS)
all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

redboot ecos: fis

clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done