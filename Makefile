#	$OpenBSD: Makefile,v 1.7 2016/10/19 14:31:19 tb Exp $

# The following ports must be installed:
#
# python-2.7		interpreted object-oriented programming language
# py-libdnet		python interface to libdnet
# scapy			powerful interactive packet manipulation in python

.if ! (make(clean) || make(cleandir) || make(obj))
# Check wether all required python packages are installed.  If some
# are missing print a warning and skip the tests, but do not fail.
PYTHON_IMPORT != python2.7 -c 'from scapy.all import *' 2>&1 || true
.endif
.if ! empty(PYTHON_IMPORT)
regress:
	@echo '${PYTHON_IMPORT}'
	@echo install python and the scapy module for additional tests
	@echo SKIPPED
.endif

# This test needs a manual setup of two machines
# Set up machines: SRC DST
# SRC is the machine where this makefile is running.
# DST is running OpenBSD with pf disabled to test the IPv6 stack.
# SRT source routed host, no packets reach this host,
#     it represents just bunch of addresses
#
# +---+   1   +---+       +---+
# |SRC| ----> |DST|       |SRT|
# +---+       +---+       +---+
#     out    in   out    in   out

# Configure Addresses on the machines.
# Adapt interface and address variables to your local setup.
#
SRC_IF ?=
SRC_MAC ?=
DST_MAC ?=

SRC_OUT6 ?=
DST_IN6 ?=
DST_OUT6 ?=
SRT_IN6 ?=
SRT_OUT6 ?=

.if empty (SRC_IF) || empty (SRC_MAC) || empty (DST_MAC) || \
    empty (SRC_OUT6) || empty (DST_IN6) || empty (DST_OUT6) || \
    empty (SRT_IN6) || empty (SRT_OUT6)
regress:
	@echo this tests needs a remote machine to operate on
	@echo SRC_IF SRC_MAC DST_MAC SRC_OUT6 DST_IN6 DST_OUT6
	@echo SRT_IN6 SRT_OUT6 are empty
	@echo fill out these variables for additional tests
	@echo SKIPPED
.endif

depend: addr.py

# Create python include file containing the addresses.
addr.py: Makefile
	rm -f $@ $@.tmp
	echo 'SRC_IF = "${SRC_IF}"' >>$@.tmp
	echo 'SRC_MAC = "${SRC_MAC}"' >>$@.tmp
	echo 'DST_MAC = "${DST_MAC}"' >>$@.tmp
.for var in SRC_OUT DST_IN DST_OUT SRT_IN SRT_OUT
	echo '${var}6 = "${${var}6}"' >>$@.tmp
.endfor
	mv $@.tmp $@

# Set variables so that make runs with and without obj directory.
# Only do that if necessary to keep visible output short.
.if ${.CURDIR} == ${.OBJDIR}
PYTHON =	python2.7 ./
.else
PYTHON =	PYTHONPATH=${.OBJDIR} python2.7 ${.CURDIR}/
.endif

TARGETS +=	rh0-none
run-regress-rh0-none: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_none.py

TARGETS +=	rh0-empty
run-regress-rh0-empty: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_empty.py

TARGETS +=	rh0-final
run-regress-rh0-final: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_final.py

TARGETS +=	rh0-route
run-regress-rh0-route: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_route.py

TARGETS +=	rh0-frag-empty
run-regress-rh0-frag-empty: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_frag_empty.py

TARGETS +=	rh0-frag-final
run-regress-rh0-frag-final: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_frag_final.py

TARGETS +=	rh0-frag-route
run-regress-rh0-frag-route: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_frag_route.py

TARGETS +=	rh0-frag2
run-regress-rh0-frag2: addr.py
	@echo '\n======== $@ ========'
	${SUDO} ${PYTHON}rh0_frag2.py

REGRESS_TARGETS =	${TARGETS:S/^/run-regress-/}

CLEANFILES +=		addr.py *.pyc *.log

.PHONY: check-setup

# Check wether the address, route and remote setup is correct
check-setup:
	@echo '\n======== $@ ========'
	route -n get -inet6 ${SRC_OUT6} | grep -q 'flags: .*LOCAL'
	ping6 -n -c 1 ${SRC_OUT6}
	route -n get -inet6 ${DST_IN6} | grep -q 'interface: ${SRC_IF}$$'
	ping6 -n -c 1 ${DST_IN6}
	route -n get -inet6 ${DST_OUT6} | grep -q 'gateway: ${DST_IN6}$$'
	ping6 -n -c 1 ${DST_OUT6}
	route -n get -inet6 ${SRT_IN6} | grep -q 'gateway: ${DST_IN6}$$'
	ndp -n ${DST_IN6} | grep -q ' ${DST_MAC} '
.if defined(REMOTE_SSH)
	ssh ${REMOTE_SSH} ${SUDO} pfctl -si | grep '^Status: Disabled '
.endif

.include <bsd.regress.mk>
