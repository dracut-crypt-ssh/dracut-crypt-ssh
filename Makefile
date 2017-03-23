include config.mk

export DESTDIR=
export MODULEDIR=${DESTDIR}$(DRACUT_MODULEDIR)

ifeq ($(NEED_CRYPTSETTLE),1)
	SUBDIRS=modules/60crypt-ssh modules/cryptsettle-patch
else
	SUBDIRS=modules/60crypt-ssh
endif

.PHONY: install all clean dist $(SUBDIRS)

all: $(SUBDIRS)

install: $(SUBDIRS)
	mkdir -p $(DESTDIR)/etc/dracut.conf.d/
	cp crypt-ssh.conf $(DESTDIR)/etc/dracut.conf.d/

clean: $(SUBDIRS)
	rm -f dracut-crypt-ssh-*gz config.mk

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

DISTNAME=dracut-crypt-ssh-$(shell git describe --tags | sed s:v::)
dist:
	git archive --format=tar --prefix=$(DISTNAME)/ HEAD | gzip -9 > $(DISTNAME).tar.gz
