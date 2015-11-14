jobname = luanodelist
texmf = $(HOME)/texmf

install:
	luatex $(jobname).ins
	mkdir -p $(texmf)/$(jobname)
	cp -f $(jobname).sty $(texmf)/$(jobname)
	cp -f $(jobname).lua $(texmf)/$(jobname)
	cp -f ansicolors.lua $(texmf)/$(jobname)

doc:
	lualatex $(jobname).dtx
	makeindex -s gglo.ist -o $(jobname).gls $(jobname).glo
	makeindex -s gind.ist -o $(jobname).ind $(jobname).idx
	lualatex $(jobname).dtx

clean:
	./.githook_pre-commit



.PHONY: all clean ctan
