INSTDIR=$(DESTDIR)/usr/libexec/dracut-earlyssh

CFLAGS=-std=gnu99 -O2 -Wall

.PHONY: all

all: console_auth unlock

clean:
	rm -f *.o console_auth unlock

install:	console_auth unlock
	mkdir -p $(INSTDIR)
	cp console_auth unlock $(INSTDIR)/

console_auth:	auth.c
	gcc $(CFLAGS) $^ -o $@

unlock:	crypttab.o unlock.o
	gcc -lblkid $^ -o $@

