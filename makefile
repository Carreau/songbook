# Copyright (c) 2008 Alexandre Dupas <alexandre.dupas@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

SRC := $(wildcard *.tex)

SONGBOOKS := $(wildcard *.sb)

SOURCES := $(shell egrep -l '^[^%]*\\begin\{document\}' *.tex)

CIBLE = $(SOURCES:%.tex=%) $(SONGBOOKS:%.sb=%)

PDF = $(CIBLE:%=%.pdf)
PSF = $(CIBLE:%=%.ps.gz)

SONGS = songs.sbd
SONGS_SRC = $(shell ls songs/*/*.sg)

CHORDS = chords.tex
CHORDS_SRC = $(shell ls songs/*/*.sg)

MAKE_INDEX=./songbook-makeindex.py
MAKE_SONGDB=./songbook-volume.py
MAKE_CHORDS=./utils/songbook-gtab.py
PRINT=printf "%s\n"
PRINTTAB=printf "\t%s\n"

ifeq ($(shell which ikiwiki),)
IKIWIKI=$(ECHO) "** ikiwiki not found" >&2 ; $(ECHO) ikiwiki
else
IKIWIKI=ikiwiki
endif

ifeq ($(shell which lilypond),)
LILYPOND=$(ECHO) "** lilypond not found" >&2 ; $(ECHO) lilypond
LILYFILE=''
else
LILYPOND=lilypond
LILYSRC=$(wildcard lilypond/*.ly)
LILYFILE=$(LILYSRC:%.ly=%.pdf)
endif

# Get dependencies (that can also have dependencies)
define get_dependencies
	deps=`perl -ne '($$_)=/^[^%]*\\\(?:include|input)\{(.*?)\}/;@_=split /,/; foreach $$t (@_) { print "$$t "}' $<`
endef

# Get inclusion only files (that can not have dependencies)
define get_inclusions
	incl=`perl -ne '($$_)=/^[^%]*\\\(?:newauthorindex|newindex)\{.*\}\{(.*?)\}/;@_=split /,/; foreach $$t (@_) { print "$$t.sbx "}' $<`
endef

define get_prereq
	prep=`perl -ne '($$_)=/^[^%]*\\\(?:newauthorindex|newindex)\{.*\}\{(.*?)\}/;@_=split /,/; foreach $$t (@_) { print "$$t.sxd "}' $<`
endef

############################################################
### Cibles

default: chordbook.pdf

all: $(PDF)

ps: $(PSF)
	gv $<

pdf: $(PDF)
	xpdf $<

lilypond: $(LILYFILE)

clean: cleandoc
	@rm -f $(SRC:%.tex=%.d)
	@rm -f $(CIBLE:%=%.aux) 
	@rm -f $(CIBLE:%=%.toc)
	@rm -f $(CIBLE:%=%.out) $(CIBLE:%=%.log) $(CIBLE:%=%.nav) $(CIBLE:%=%.snm)
	@rm -f $(CIBLE:%=%.dvi)
	@rm -f $(SONGS)
	@rm -f *.sbd
	@rm -f *.sbx *.sxd
	@rm -f ./lilypond/*.ps
	@rm -f $(SONGBOOKS:%.sb=%.tex)

cleanall: clean
	@rm -f $(PDF) $(PSF)
	@rm -f $(LILYFILE)

depend:

doc : documentation

documentation:
	$(IKIWIKI) doc html -v --wikiname "Songbook Documentation" --plugin=goodstuff --set usedirs=0

cleandoc:
	@rm -rf "doc/.ikiwiki" html

############################################################

$(PSF): LATEX = latex
$(PSF): %.ps.gz: %.ps
	gzip -f $<

%.ps: %.dvi
	dvips -o $@ $<

%.dvi: %.tex %.aux
	$(LATEX) $<

$(PDF): LATEX = pdflatex
$(PDF): %.pdf: %.tex %.aux

%.aux: %.tex
	$(LATEX) $< 

%.sbx: %.sxd
	$(MAKE_INDEX) $< > $@

%.d: %.tex
	@$(get_dependencies) ; $(PRINT) "$< $@: $$deps" > $@
	@$(get_inclusions) ; $(PRINT) "$(patsubst %.tex,%.pdf,$<) : $$incl" >> $@ ; $(PRINTTAB) "\$$(LATEX) $<" >> $@ ;
	@$(get_prereq) ; $(PRINT) "$$prep : $(patsubst %.tex,%.aux,$<)" >> $@ ; 

include $(SOURCES:%.tex=%.d)

# songbook related rules
%.aux: $(SONGS)

COMMA=,
$(SONGS): $(SONGS_SRC)
	@$(PRINT) "\graphicspath{{img/},$(patsubst %,{%}$(COMMA),$(dir $(SONGS_SRC)))}" > $@
	@cat $(SONGS_SRC) >> $@

%.sbd: %.sgl
	@$(MAKE_SONGDB) --songs=$< --output=$@

%.pdf: %.ly
	@$(LILYPOND) --output=$(@:%.pdf=%) $<
	@rm $(@:%.pdf=%.ps)

$(CHORDS): $(CHORDS_SRC)
	$(MAKE_CHORDS) -o $@

%.tex: %.sb
	$(PRINT) "\newcommand{\template}{" > $@
	cat $< >> $@
	$(PRINT) "}" >> $@
	$(PRINT) "\input{template.tex}" >> $@

# Create an empty mybook.sgl file if it does not exist
mybook.sgl:
	touch $@
