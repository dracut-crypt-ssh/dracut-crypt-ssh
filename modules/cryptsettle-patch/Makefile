INSTDIR=$(MODULEDIR)/91cryptsettle-patch/

.phony: install all clean

all:	

clean:
	

install:	../install.sh ../check.sh module-setup.sh
	mkdir -p $(INSTDIR)
	install -m 0755 module-setup.sh $(INSTDIR)/
ifeq ($(OLDSTYLE),1)
	install -m 0755 ../install.sh $(INSTDIR)/install
	install -m 0755 ../check.sh $(INSTDIR)/check
endif
