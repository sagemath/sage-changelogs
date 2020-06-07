all: merger bin/parseticket bin/getrealname

bin/parseticket: parseticket.c
	gcc -std=gnu99 -O $< -o $@

bin/getrealname: getrealname.c
	gcc -std=gnu99 -O $< -o $@
