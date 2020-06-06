/*
 * parseticket.c: parse a CSV ticket from http://trac.sagemath.org/
 * 
 * Read a ticket in CSV format from standard input.  Such a ticket comes from
 * a URL like "http://trac.sagemath.org/sage_trac/ticket/4000?format=csv".
 * Output to standard output a file where every line is of the form
 * "key:value", containing all fields in the ticket except "description".
 * If file descriptor 6 exists, the "description" of the ticket is written
 * there verbatim.
 * This program takes no arguments, any arguments will be ignored anyway.
 *
 * Example use in a shell pipeline:
 * wget -O- "http://trac.sagemath.org/sage_trac/ticket/${ticket}?format=csv" \
 *     | parseticket >ticket.txt 6>ticket.desc
 *
 * Example standard output:
 *   id:4000
 *   summary:Implement QQ['x'] via Flint ZZ['x'] + denominator
 *   reporter:malb
 *   owner:somebody
 *   type:enhancement
 *   status:closed
 *   priority:blocker
 *   milestone:sage-4.6
 *   component:basic arithmetic
 *   resolution:fixed
 *   keywords:
 *   cc:burcin drkirkby spancratz mhansen malb jdemeyer pjeremy
 *   author:Sebastian Pancratz, Martin Albrecht, William Stein, Jeroen Demeyer, Robert Beezer
 *   upstream:N/A
 *   reviewer:John Cremona, Martin Albrecht, Alex Ghitza, Harald Schilly, William Stein, Mitesh Patel
 *   merged:sage-4.6.alpha3
 *   work_issues:
 * 
 * AUTHORS:
 * 
 * - Jeroen Demeyer (2010-10-24): initial version for sage-4.6.1
 * 
 */

/*****************************************************************************
 *       Copyright (C) 2010 Jeroen Demeyer <jdemeyer@cage.ugent.be>
 *
 * Distributed under the terms of the GNU General Public License (GPL) as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 *                  http://www.gnu.org/licenses/
 *****************************************************************************/


#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <assert.h>

/*
 * Read one line of a CSV file.
 * 
 * INPUT:
 *
 *  - *ptr: pointer to start of line to read.
 *
 *  - cells, ncells: ``cells`` is an (uninitialized) array of ``ncells``
 *    pointers to char.
 *
 * OUTPUT:
 *
 *  - return value: number of cells read
 *
 *  - *ptr: pointer to the start of the next line (or null-terminator)
 *
 *  - cells[i]: pointer to the ``i``-th cell
 *
 * NOTE that the string pointed to by *ptr will be changed.  Any
 * characters between the input value of *ptr and the output value of
 * *ptr are unspecified.  The ``cells`` array will contains pointers to
 * this space.
 */
int readcsvline(char** ptr, char** cells, int ncells)
{
	assert(ncells > 0);

	int cell = 0;
	int quote = 0;
	const char* in = *ptr;
	char* out = *ptr;

	cells[cell++] = out;
	for (;;)
	{
		char c = *(in++);
		if (c == 0) goto finished;

		assert(out < in);
		if (quote)
		{
			switch (c)
			{
				case '"':
					if (*in == '"')
					{
						/* Double quote -> make it single quote */
						in++;
						*(out++) = '"';
					}
					else
					{
						/* End quote */
						quote = 0;
					}
					break;
				case '\r': /* Ignore */
					break;
				default:
					*(out++) = c;
			}
		}
		else
		{
			switch (c)
			{
				case '"':
					/* Start quote */
					quote = 1;
					break;
				case ',':
					/* End cell, start a new one */
					*(out++) = 0;
					if (cell >= ncells) {fprintf(stderr, "Too many columns (>= %i)\n", ncells); exit(1);}
					cells[cell++] = out;
					break;
				case '\r': /* Ignore */
					break;
				case '\n':
					goto finished;
				default:
					*(out++) = c;
			}
		}
	}

finished:
	*out = 0;
	*ptr = (char*)(in);
	return cell;
}


int main(int argc, char** argv)
{
	/* Read stdin completely until EOF */
	size_t input_bufsize = 0;
	size_t input_size = 0;
	char* input = NULL;
	for (;;)
	{
		if (input_size >= input_bufsize)
		{
			input_bufsize *= 2;
			if (input_bufsize < 128) input_bufsize = 128;
			input = realloc(input, input_bufsize);
			if (!input)
			{
				fprintf(stderr, "Failed to allocate %lu bytes\n", input_bufsize);
				exit(3);
			}
		}
		ssize_t r = read(0, input + input_size, input_bufsize - input_size);
		if (r < 0) {perror("read"); exit(2);}
		if (r == 0) break;
		input_size += r;
	}
	close(0);

	/* First line: keys; second line: values */
	char* keys[64];
	char* values[64];
	int nkeys = readcsvline(&input, keys, 64);
	int nvalues = readcsvline(&input, values, 64);

	if (nkeys != nvalues)
	{
		fprintf(stderr, "Number of keys (%i) does not equal number of values (%i)\n", nkeys, nvalues);
		exit(1);
	}

	/* Process all key/value pairs */
	int i;
	for (i = 0; i < nkeys; i++)
	{
		const char* k = keys[i];
		char* v = values[i];

		/* Special case: description */
		if (!strcmp(k, "description"))
		{
			/* Write description to fd 6 */
			write(6, v, strlen(v));
			continue;
		}

		/* Replace all newlines in v by spaces */
		char* ptr;
		for (ptr = v; *ptr; ++ptr) if (*ptr == '\n') *ptr = ' ';

		/* Write k:v to stdout */
		printf("%s:%s\n", k, v);
	}

	return 0;
}
