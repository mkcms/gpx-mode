emacs ?= emacs
FILES := gpx.el
ELC := $(FILES:.el=.elc)

compile: $(ELC)

%.elc: %.el
	${emacs} -Q --batch -L . -f batch-byte-compile $<

# Run emacs -Q with gpx.el loaded
_baremacs: ${ELC}
	${emacs} -Q ${PACKAGE_INIT} ${KEYMAP} ${TEST_ARGS}                    \
                -L . -l gpx

update-copyright-years:
	year=`date +%Y`;                                                      \
	sed -i *.el -r                                                        \
	  -e 's/Copyright \(C\) ([0-9]+)(-[0-9]+)?/Copyright (C) \1-'$$year'/'

clean:
	rm -f *.elc
