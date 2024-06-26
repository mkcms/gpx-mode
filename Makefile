emacs ?= emacs
FILES := gpx.el
ELC := $(FILES:.el=.elc)

# Sexp to fill paragraphs in the commentary section.
FILL_COMMENTARY := --eval '(progn                                              \
	(delete-trailing-whitespace)                                           \
        (setq fill-column 74)                                                  \
	(fill-individual-paragraphs (search-forward "Commentary:")             \
	                            (search-forward ";;; Configuration"))      \
	(save-buffer))'

compile: $(ELC)

%.elc: %.el
	${emacs} -Q --batch -L .                                               \
	    --eval '(setq byte-compile-error-on-warn t)'                       \
	    -f batch-byte-compile $<

lint:
	file=$$(mktemp)                                                        \
	&& ${emacs} -Q --batch gpx.el                                          \
		--eval '(checkdoc-file (buffer-file-name))' 2>&1 | tee $$file  \
	&& test -z "$$(cat $$file)"                                            \
	&& (grep -n -E "^.{80,}" gpx.el `# Catch long lines`                   \
	    | sed                                                              \
		-r 's/^([0-9]+).*/gpx.el:\1: Too long/;q1')

# Run emacs -Q with gpx.el loaded
_baremacs: ${ELC}
	${emacs} -Q ${PACKAGE_INIT} ${KEYMAP} ${TEST_ARGS}                    \
                -L . -l gpx

update-copyright-years:
	year=`date +%Y`;                                                      \
	sed -i *.el -r                                                        \
	  -e 's/Copyright \(C\) ([0-9]+)(-[0-9]+)?/Copyright (C) \1-'$$year'/'

readme-to-el:
	sed README.md -r                                                      \
	    -e 's/^#+ (.*) #*$$/\n;;; \1/'      `# Rewrite headers`           \
	    -e '/^.*License.*/,/^<!/d'          `# Delete license`            \
	    -e '/.*screenshot.png.*/,/^$$/d'    `# Delete screenshot`         \
	    -e '/^<!--/d'                       `# Remove comments`           \
	    -e 's/^/;; /'                       `# Add lisp comment char`     \
	    -e 's/Emacs package/Package/g'      `# It's obviously for Emacs`  \
	    -e 's/(\[(.*)\]){2,}/\1/g'                                        \
	    >  commentary.txt                                                 \
	&& ( sed '1,/^;;; Commentary:/p;d' gpx.el                             \
	&& echo && cat commentary.txt && echo                                 \
	&& sed '/^;;; Code:/,//p;d' gpx.el ) > changed.txt                    \
	&& rm commentary.txt && mv changed.txt gpx.el                         \
	&& ${emacs} -Q --batch gpx.el ${FILL_COMMENTARY}

clean:
	rm -f *.elc
