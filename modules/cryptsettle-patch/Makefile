INSTDIR=$(MODULEDIR)/91cryptsettle-patch/

.phony: install all clean

all:	

clean:
	

install:	install.sh check.sh
	mkdir -p $(INSTDIR)
	cp install.sh $(INSTDIR)/install
	cp check.sh $(INSTDIR)/check
	chmod 755 $(INSTDIR)/{install,check}

