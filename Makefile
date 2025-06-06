jobname = nodetree
texmf = $(HOME)/texmf
texmftex = $(texmf)/tex/lualatex
installdir = $(texmftex)/$(jobname)

all: install doc

install: uninstall_texlive install_dev

uninstall_texlive:
	-tlmgr uninstall --force nodetree

install_dev:
	luatex $(jobname).ins
	mkdir -p $(installdir)
	cp -f $(jobname).tex $(installdir)
	cp -f $(jobname).sty $(installdir)
	cp -f $(jobname)-embed.sty $(installdir)
	cp -f $(jobname).lua $(installdir)
	./clean.sh install

doc: doc_examples doc_pdf doc_lua

doc_pdf:
	lualatex --shell-escape $(jobname)-doc.tex
	makeindex -s gglo.ist -o $(jobname)-doc.gls $(jobname)-doc.glo
	makeindex -s gind.ist -o $(jobname)-doc.ind $(jobname)-doc.idx
	lualatex --shell-escape $(jobname)-doc.tex
	mkdir -p $(texmf)/doc
	cp $(jobname)-doc.pdf $(texmf)/doc

doc_examples:
	find . -name "*_nodetree.tex" -exec rm -f {} \;
	find examples -name "*.tex" -exec latexmk -latex=lualatex -cd {} \;

doc_lua:
	ldoc -a .

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
	cp -f $(jobname)-doc.tex $(jobname)/
	cp -f $(jobname)-doc.pdf $(jobname)/
	cp -f $(jobname).lua $(jobname)/
	tar cvfz $(jobname).tar.gz $(jobname)
	rm -rf $(jobname)

.PHONY: all install doc clean test ctan test_lualatex test_luatex doc_lua
