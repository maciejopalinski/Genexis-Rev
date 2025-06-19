PYTHON := python3
VENV := .venv
PIP := $(VENV)/bin/pip
JEFFERSON := $(VENV)/bin/jefferson

all: jffs2

jffs2: jffs2/extracted/

jffs2/extracted/: jffs2/jffs2.img $(JEFFERSON)
	$(JEFFERSON) -d $@ $<
	find $@ -type f -exec shasum {} \;

clean:
	rm -rf ./jffs2/extracted/

distclean: clean
	rm -rf $(VENV)

$(VENV):
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip

$(JEFFERSON): $(VENV)
	$(PIP) install jefferson