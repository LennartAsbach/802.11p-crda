ifeq ($(origin $(KLIB)), undefined)
KLIB := /lib/modules/$(shell uname -r)
endif
KLIB_BUILD ?= $(KLIB)/build

CFLAGS += -Wall -g3
#CFLAGS += -DUSE_OPENSSL
#LDFLAGS += -lssl
ifneq ($(COMPAT_TREE),)
CFLAGS += -I$(COMPAT_TREE)/include/
endif
CFLAGS += -I$(KLIB_BUILD)/include -DUSE_GCRYPT
LDFLAGS += -lgcrypt

MKDIR ?= mkdir -p
INSTALL ?= install

CRDA_LIB = "/usr/lib/crda/"

all: regulatory.bin warn crda
	@$(MAKE) --no-print-directory -f Makefile verify

regulatory.bin:	db2bin.py key.priv.pem db.txt dbparse.py
	@./db2bin.py regulatory.bin db.txt key.priv.pem

crda: keys-ssl.c keys-gcrypt.c regdb.h regdb.o crda.o
	$(CC) $(CFLAGS) $(LDFLAGS) -lnl -o $@ regdb.o crda.o

clean:
	@rm -f regulatory.bin crda dump *.o *~ *.pyc keys-*.c
	@if test -f key.priv.pem && diff -qNs test-key key.priv.pem >/dev/null ; then \
	rm -f key.priv.pem;\
	fi

warn:
	@if test ! -f key.priv.pem || diff -qNs test-key key.priv.pem >/dev/null ; then \
	echo '**************************************';\
	echo '**  WARNING!                        **';\
	echo '**  No key found, using TEST key!   **';\
	echo '**************************************';\
	fi

key.priv.pem:
	cp test-key key.priv.pem

generate_key:
	openssl genrsa -out key.priv.pem 2048

dump: keys-ssl.c keys-gcrypt.c regdb.h regdb.o dump.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ regdb.o dump.o

keys-ssl.c: key2pub.py $(wildcard *.pem)
	@./key2pub.py --ssl *.pem > keys-ssl.c

keys-gcrypt.c: key2pub.py $(wildcard *.pem)
	@./key2pub.py --gcrypt *.pem > keys-gcrypt.c

verify: dump
	@./dump regulatory.bin >/dev/null

install: regulatory.bin crda
	$(MKDIR) $(DESTDIR)$(CRDA_LIB)
	$(INSTALL) -m 644 -t $(DESTDIR)$(CRDA_LIB) regulatory.bin
	$(INSTALL) -m 755 -t $(DESTDIR)/sbin/ crda
	$(INSTALL) -m 644 -t $(DESTDIR)/etc/udev/rules.d/ regulatory.rules
