INSTDIR=$(MODULEDIR)/60earlyssh

all:	module-setup.sh

clean:	
	rm -f module-setup.sh

module-setup.sh:	module-setup.sh.in
	sed -e "s!@ROOTHOME@!${ROOTHOME}!g" \
	    -e "s!@OLDSTYLE@!${OLDSTYLE}!g" \
	    -e "s!@NSSFILES@!${NSSFILES}!g" \
	       < module-setup.sh.in > module-setup.sh

install:	50-udev-pty.rules console_peek.sh ../install.sh ../check.sh
	mkdir -p $(INSTDIR)
	install -m 0644 50-udev-pty.rules $(INSTDIR)/
	install -m 0755 unlock-reap-success.sh console_peek.sh $(INSTDIR)/
	install -m 0755 module-setup.sh $(INSTDIR)
ifeq ($(OLDSTYLE),1)
	install -m 0755 ../install.sh $(INSTDIR)/install
	install -m 0755 ../check.sh $(INSTDIR)/check
	install -m 0755 dummyroot $(INSTDIR)/
endif

