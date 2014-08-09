INSTDIR=$(MODULEDIR)/60earlyssh

all:	module-setup.sh

clean:	
	rm -f module-setup.sh

module-setup.sh:	module-setup.sh.in
	sed -e "s!@ROOTHOME@!${ROOTHOME}!g" \
	    -e "s!@OLDDRACUT@!${OLDDRACUT}!g" \
	    -e "s!@LIBDIR@!${LIBDIR}!g" \
	       < module-setup.sh.in > module-setup.sh

install:	50-udev-pty.rules console_peek.sh
	mkdir -p $(INSTDIR)
	cp 50-udev-pty.rules $(INSTDIR)/
	cp console_peek.sh $(INSTDIR)/
	chmod 755 $(INSTDIR)/console_peek.sh
ifeq ($(OLDDRACUT),1)
	cp install.sh $(INSTDIR)/install
	cp check.sh $(INSTDIR)/check
	cp dummyroot $(INSTDIR)/
	chmod 755 $(INSTDIR)/{install,check,dummyroot}
endif

