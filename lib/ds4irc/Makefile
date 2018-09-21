mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE := $(current_dir)
PREFIX ?= ~/.hammerspoon
MODPATH = extensions
VERSION ?= 0.1
HS_APPLICATION ?= /Applications

CFILE = ${wildcard *.c}
HEADERS  = ${wildcard *.h}

# swap if all c files should be compiled into one target -- this is necessary if you organize your code in
# multiple files but need them to access functions/objects defined in different files -- each dynamic library is loaded
# individually by Hammerspoon so they can't see the exports of each other directly.
# SOFILE := $(CFILE:.c=.so)
SOFILE  := init.so
DEBUG_CFLAGS ?= -g

# special vars for uninstall
space :=
space +=
comma := ,
ALLFILES := $(LUAFILE)
ALLFILES += $(SOFILE)

.SUFFIXES: .c .so

#CC=cc
CC=@clang
WARNINGS ?= -Weverything -Wno-padded -Wno-vla -Wno-gnu-statement-expression -Wno-covered-switch-default -Wno-missing-prototypes -Werror-implicit-function-declaration
EXTRA_CFLAGS ?= -I$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks/LuaSkin.framework/Headers

CFLAGS  += $(DEBUG_CFLAGS) -fmodules -fobjc-arc -DHS_EXTERNAL_MODULE $(WARNINGS) $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: $(SOFILE)

# release: clean all
# 	HS_APPLICATION=$(HS_APPLICATION) PREFIX=tmp make install ; cd tmp ; tar -cf ../$(MODULE)-v$(VERSION).tar hs ; cd .. ; gzip $(MODULE)-v$(VERSION).tar
#
# releaseWithDocs: clean all docs
# 	HS_APPLICATION=$(HS_APPLICATION) PREFIX=tmp make install ; cd tmp ; tar -cf ../$(MODULE)-v$(VERSION).tar hs ; cd .. ; gzip $(MODULE)-v$(VERSION).tar

# swap if all c files should be compiled into one target
# .c.so: $(HEADERS) $(CFILE)
# 	$(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

init.so: $(HEADERS) $(CFILE)
	$(CC) $(CFILE) $(CFLAGS) $(LDFLAGS) -o $@

install:
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODPATH)/$(MODULE)
# swap if all c files should be compiled into one target
	# cp -vpR $(CFILE:.c=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE)
	cp -vpR $(SOFILE:.so=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE)

# .PHONY docs
# docs:
# 	hs -c "require(\"hs.doc\").builder.genJSON(\"$(dir $(mkfile_path))\")" > docs.json

clean:
	rm -rf $(SOFILE) *.dSYM tmp

uninstall:
	rm -v -f $(PREFIX)/$(MODPATH)/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
# swap if all c files should be compiled into one target
	# (pushd $(PREFIX)/$(MODPATH)/$(MODULE)/ ; rm -v -fr $(CFILE:.c=.so.dSYM) ; popd)
	(pushd $(PREFIX)/$(MODPATH)/$(MODULE)/ ; rm -v -fr $(SOFILE:.so=.so.dSYM) ; popd)
	rmdir -p $(PREFIX)/$(MODPATH)/$(MODULE) ; exit 0

.PHONY: all clean uninstall install
