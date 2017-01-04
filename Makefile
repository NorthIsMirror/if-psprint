# $Id: Makefile,v 1.1 2001/12/14 15:37:24 abs Exp $
#

PKGNAME=if-psprint
PROG=${PKGNAME}
MANSECTION=8
FILES=Makefile ${PROG}.pl README
GENFILES=${PROG} ${PKGNAME}.${MANSECTION}
VERSION!=perl -T ./${PROG}.pl -V

INSTALL_DATA	?= install -m 0644
INSTALL_DIR	?= install -d
INSTALL_MAN	?= install -m 0644
INSTALL_PROGRAM ?= install -m 0755
INSTALL_SCRIPT	?= install -m 0755
SYSCONFDIR	?= ${PREFIX}/etc
PREFIX 		?= /usr/local

all:	${GENFILES}

tar:
	mkdir -p ${PKGNAME}-${VERSION}
	cp  ${FILES} ${PKGNAME}-${VERSION}
	tar cvf - ${PKGNAME}-${VERSION} | bzip2 -9 > ${PKGNAME}-${VERSION}.tbz
	rm -rf ${PKGNAME}-${VERSION}

test:
	perl -wTc ${PROG}

clean:	
	rm -f ${GENFILES} ${PKGNAME}-*.tbz *~~

install: ${PKGNAME}.${MANSECTION}
	${INSTALL_DIR} ${DESTDIR}${PREFIX}/libexec
	${INSTALL_SCRIPT} ${PROG} ${DESTDIR}${PREFIX}/libexec/${PKGNAME}
	${INSTALL_DIR} ${DESTDIR}${PREFIX}/man/man${MANSECTION}
	${INSTALL_MAN} ${PKGNAME}.${MANSECTION} ${DESTDIR}${PREFIX}/man/man${MANSECTION}

# GENFILES

${PROG}: ${PROG}.pl Makefile
	sed -e 's:/usr/local:${PREFIX}:'  < ${PROG}.pl > ${PROG}
	chmod 755 ${PROG}

${PKGNAME}.${MANSECTION}:	${PROG}
	pod2man ${PROG} > ${PKGNAME}.${MANSECTION}
