#! /bin/sh

_install() {
	HOOKS='.git/hooks'
	echo "$2" > "$HOOKS/$1"
	chmod a+x "$HOOKS/$1"
}

CLEAN='
EXT=".aux .fdb_latexmk .glo .gls .fls .ilg .ind .idx .log .out .pdf .synctex.gz .tar.gz .toc _nodetree.tex _nodetree.log"

_remove() {
	find . -iname "*$1" -not -path "./.git*" -exec rm -f {} \;
}

for i in $EXT; do
	_remove $i
done'

if [ "$1" = 'install' ]; then
	_install 'pre-commit' "#! /bin/sh $CLEAN"
else
	eval "$CLEAN"
fi
