#! /bin/sh

# Symlink to .git/hooks/pre-commit

_remove() {
	find . -iname "*.$1" -exec rm -f {} \;
}

_remove pdf
_remove aux
_remove log
_remove fdb_latexmk
_remove synctex.gz
_remove out