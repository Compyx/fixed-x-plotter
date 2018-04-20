# vim: set noet ts=8 sw=8 sts=8 :
#
# Makefile for the fixed-X-plotter

VPATH = src

LABELS = labels.txt
ASM = 64tass
ASM_FLAGS = --ascii --case-sensitive --m6502 --vice-labels --labels $(LABELS) \
	-Wall -Wshadow -Wstrict-bool

TARGET = plotter.prg


DATA = 
HEADERS = 
SOURCES = main.s

all : $(TARGET)

$(TARGET) : $(SOURCES) $(HEADERS) $(DATA)
	$(ASM) $(ASM_FLAGS) -o $@ main.s

optimize: $(SOURCES) $(HEADERS) $(DATA)
	$(ASM) $(ASM_FLAGS) -Woptimize -o $(TARGET) main.s



.PHONY: clean

clean:
	rm -f $(TARGET)
	rm -f $(LABELS)

