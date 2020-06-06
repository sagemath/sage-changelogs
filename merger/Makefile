all: merger bin/parseticket bin/getrealname bin/ifoutput bin/die

merger: merger.c
	gcc -std=gnu99 -O $< -o $@

bin/parseticket: parseticket.c
	gcc -std=gnu99 -O $< -o $@

bin/getrealname: getrealname.c
	gcc -std=gnu99 -O $< -o $@

bin/ifoutput: ifoutput.c
	gcc -std=gnu99 -O $< -o $@

bin/die: die.c
	gcc -std=gnu99 -O $< -o $@
