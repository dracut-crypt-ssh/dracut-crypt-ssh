include config.mk

export DESTDIR=
export MODULEDIR=${DESTDIR}/usr/$(DRACUT_MODULEDIR)

ifeq ($(NEED_CRYPTSETTLE),1)
	SUBDIRS=modules/60crypt-ssh modules/cryptsettle-patch
else
	SUBDIRS=modules/60crypt-ssh
endif

.PHONY: install all clean $(SUBDIRS)

all: $(SUBDIRS)

install: $(SUBDIRS)
	mkdir -p $(DESTDIR)/etc/dracut.conf.d/
	cp crypt-ssh.conf $(DESTDIR)/etc/dracut.conf.d/

clean: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
