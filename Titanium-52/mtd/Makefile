# List of image-target names and corresponding mtdblock numbers
MTD_IMAGES = \
	Bootstrap:0 \
  	JFFS2:1 \
  	Bootloader1:2 \
  	Bootloader2:3 \
  	UniqueParam:4 \
  	BootloaderCFG:5 \
  	SharedCFG:6

# Convert names into targets
IMAGES := $(foreach pair,$(MTD_IMAGES),$(word 1,$(subst :, ,$(pair))).img)

# Default target
all: $(IMAGES)

# Pattern rule to link .img to corresponding mtdblock
%.img:
	@block=$(shell echo $(MTD_IMAGES) | tr ' ' '\n' | grep "^$*:" | cut -d: -f2); \
	if [ -z "$$block" ]; then \
	  echo "Error: No mtdblock number defined for $*.img" >&2; exit 1; \
	fi; \
	ln -vsf ../mtd/mtdblock$$block $@

clean:
	rm -rf *.img