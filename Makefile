
export VERSION=1.0.2

include config.mk

export DESTDIR=
export MODULEDIR=${DESTDIR}/usr/$(DRACUT_MODULEDIR)

SUBDIRS=modules/earlyssh modules/cryptsettle-patch src

ifeq ($(NEED_CRYPTSETTLE),1)
	CRYPTSETTLE=modules/cryptsettle-patch
else
	CRYPTSETTLE=
endif

.PHONY:	src dist $(SUBDIRS)

all: src $(CRYPTSETTLE) modules/earlyssh

install:	src modules/earlyssh $(CRYPTSETTLE)
	mkdir -p $(DESTDIR)/etc/dracut.conf.d/
	cp earlyssh.conf $(DESTDIR)/etc/dracut.conf.d/

clean:	src modules/earlyssh modules/cryptsettle-patch

dist:	
	$(MAKE) clean
	mkdir -p tmp/dracut-earlyssh-${VERSION}
	cp -R configure src modules Makefile earlyssh.conf COPYING README.md tmp/dracut-earlyssh-${VERSION}
	tar -C tmp -czf ../dracut-earlyssh-${VERSION}.tgz dracut-earlyssh-${VERSION}
	rm -rf tmp

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)


