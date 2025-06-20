PYTHON := python3
VENV := .venv
PIP := $(VENV)/bin/pip
JEFFERSON := $(VENV)/bin/jefferson

SUBDIRS := drgboot drgldr drgos jffs2 unique-param

.PHONY: all clean distclean $(SUBDIRS)
all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

jffs2: $(JEFFERSON)

drgos: jffs2

clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done

distclean: clean
	rm -rf $(VENV)

$(VENV):
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip

$(JEFFERSON): $(VENV)
	$(PIP) install jefferson