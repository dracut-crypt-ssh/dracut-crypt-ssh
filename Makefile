
export VERSION=1.0.2

export OLDDRACUT=0
export LIBDIR=/lib
export ROOTHOME=/root/

export DESTDIR=
export MODULEDIR=${DESTDIR}/usr/share/dracut/modules.d/

SUBDIRS=modules/earlyssh modules/cryptsettle-patch src

ifeq ($(OLDDRACUT),1)
	CRYPTSETTLE=modules/cryptsettle-patch
else
	CRYPTSETTLE=
endif

.PHONY:	src dist $(SUBDIRS)

all: $(CRYPTSETTLE) modules/earlyssh

install:	src modules/earlyssh $(CRYPTSETTLE)
	mkdir -p $(DESTDIR)/etc/dracut.conf.d/
	cp earlyssh.conf $(DESTDIR)/etc/dracut.conf.d/

clean:	src modules/earlyssh modules/cryptsettle-patch

dist:	
	$(MAKE) clean
	mkdir -p tmp/dracut-earlyssh-${VERSION}
	cp -R src modules Makefile earlyssh.conf COPYING README.md tmp/dracut-earlyssh-${VERSION}
	tar -C tmp -czf ../dracut-earlyssh-${VERSION}.tgz dracut-earlyssh-${VERSION}
	rm -rf tmp

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)


