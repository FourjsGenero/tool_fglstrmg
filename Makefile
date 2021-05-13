FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))

PROGMOD=fglstrmg.42m

all: $(PROGMOD) $(FORMS)

run: all
	fglrun fglstrmg

%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -Wall -M $<

clean::
	rm -f *.42?
	# rm -f *.sch -- do not remove!
