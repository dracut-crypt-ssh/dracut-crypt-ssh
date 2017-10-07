INSTDIR=$(MODULEDIR)/60crypt-ssh

SUBDIRS=helper
.PHONY: install all clean $(SUBDIRS)

all: $(SUBDIRS)

clean: $(SUBDIRS)

install: $(SUBDIRS)
	mkdir -p $(INSTDIR)
	install -m 0644 50-udev-pty.rules $(INSTDIR)/
	install -m 0755 dropbear-start.sh dropbear-stop.sh $(INSTDIR)/
	install -m 0755 module-setup.sh $(INSTDIR)/
	install -m 0644 sshd_config $(INSTDIR)/

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
