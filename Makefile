jobname = nodetree
texmf = $(HOME)/texmf
texmftex = $(texmf)/tex/lualatex
installdir = $(texmftex)/$(jobname)

all: install doc

install:
	luatex $(jobname).ins
	mkdir -p $(installdir)
	cp -f $(jobname).tex $(installdir)
	cp -f $(jobname).sty $(installdir)
	cp -f $(jobname).lua $(installdir)
	./clean.sh install

doc: doc_examples doc_pdf

doc_pdf:
	lualatex --shell-escape $(jobname).dtx
	makeindex -s gglo.ist -o $(jobname).gls $(jobname).glo
	makeindex -s gind.ist -o $(jobname).ind $(jobname).idx
	lualatex --shell-escape $(jobname).dtx
	mkdir -p $(texmf)/doc
	cp $(jobname).pdf $(texmf)/doc

doc_examples:
	find . -name "*_nodetree.tex" -exec rm -f {} \;
	find examples -name "*.tex" -exec latexmk -latex=lualatex -cd {} \;

doc_lua:
	ldoc .

clean:
	./clean.sh

test: test_luatex test_lualatex

test_lualatex:
	find tests/lualatex -name "*.tex" -exec lualatex {} \;

test_luatex:
	find tests/luatex -name "*.tex" -exec luatex {} \;

ctan: install doc
	rm -rf $(jobname)
	mkdir $(jobname)
	cp -f README.md $(jobname)/
	rm -f $(jobname)/README.md.bak
	cp -f $(jobname).ins $(jobname)/
	cp -f $(jobname).dtx $(jobname)/
	cp -f $(jobname).pdf $(jobname)/
	tar cvfz $(jobname).tar.gz $(jobname)
	rm -rf $(jobname)

.PHONY: all install doc clean test ctan test_lualatex test_luatex doc_lua
