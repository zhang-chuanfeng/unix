DIRS = lib
ROOT = .

include Make.defines.linux

*: $@

%:	%.c $(LIBAPUE)
	$(CC) $(CFLAGS) $@.c -o $@ $(LDFLAGS) $(LDLIBS)

clean:
	for i in $(DIRS); do \
		(cd $$i && echo "cleaning $$i" && $(MAKE) clean) || exit 1; \
	done  && \
	find ./ -not -name "." -not -name "*.c" -not -name "Makefile" \
		-not -name "Make.*" -not -type d -not -name "*.h" \
		| grep -v .git | grep -v *.md | grep -v .vs* \
		| xargs rm -rf

include $(ROOT)/Make.libapue.inc
