#! /bin/sh

find . -iname "*.pdf" -exec rm -f {} \;
find . -iname "*.aux" -exec rm -f {} \;
find . -iname "*.log" -exec rm -f {} \;
find . -iname "*.fdb_latexmk" -exec rm -f {} \;
find . -iname "*.synctex.gz" -exec rm -f {} \;