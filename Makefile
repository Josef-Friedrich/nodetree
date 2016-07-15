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

doc: docexamples docpdf

docpdf:
	lualatex $(jobname).dtx
	makeindex -s gglo.ist -o $(jobname).gls $(jobname).glo
	makeindex -s gind.ist -o $(jobname).ind $(jobname).idx
	lualatex $(jobname).dtx
	mkdir -p $(texmf)/doc
	cp $(jobname).pdf $(texmf)/doc

docexamples:
	find . -name "*_nodetree.tex" -exec rm -f {} \;
	find examples -name "*.tex" -exec lualatex {} \;

clean:
	./clean.sh

test: testluatex testlualatex

testlualatex:
	find tests/lualatex -name "*.tex" -exec lualatex {} \;

testluatex:
	find tests/luatex -name "*.tex" -exec luatex {} \;

ctan: install doc
	rm -rf $(jobname)
	mkdir $(jobname)
	cp -f README.md $(jobname)/
	sed -i '.bak' 's#(graphics/#(https://raw.githubusercontent.com/Josef-Friedrich/nodetree/master/graphics/#' $(jobname)/README.md
	rm -f $(jobname)/README.md.bak
	cp -f $(jobname).ins $(jobname)/
	cp -f $(jobname).dtx $(jobname)/
	cp -f $(jobname).pdf $(jobname)/
	tar cvfz $(jobname).tar.gz $(jobname)
	rm -rf $(jobname)

.PHONY: all install doc clean test ctan testlualatex testluatex
