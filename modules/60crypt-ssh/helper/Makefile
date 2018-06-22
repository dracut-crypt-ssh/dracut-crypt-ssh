INSTDIR=$(MODULEDIR)/60crypt-ssh/helper
CFLAGS+=-std=gnu99 -Wall
CC?=gcc

.PHONY: install all clean test

all: console_auth unlock

test:	crypttab-test

install:
	mkdir -p $(INSTDIR)
	install -m 0755 console_peek.sh unlock-reap-success.sh $(INSTDIR)/
	install -m 0755 unlock console_auth $(INSTDIR)/

clean:
	rm -f *.o console_auth unlock crypttab-test

console_auth:	auth.c
	$(CC) $(CFLAGS) $^ -o $@

unlock:	crypttab.o unlock.o
	$(CC) $(CFLAGS) $^ -o $@ -lblkid

crypttab-test: crypttab-test.c crypttab.o crypttab-test-data
	$(CC) crypttab-test.c $(CFLAGS) crypttab.o -lblkid -o crypttab-test
	./crypttab-test
