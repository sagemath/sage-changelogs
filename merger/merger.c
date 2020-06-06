/*
 * merger.c: C wrapper around the merger shell scripts.
 * 
 * AUTHORS:
 * 
 * - Jeroen Demeyer (2010-11-10): initial version for sage-4.6.1
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char** argv)
{
	/* Run with slightly lower priority */
	nice(5);

	/* There should be at least one command line option: the merge script */
	if (argc < 2)
	{
		fprintf(stderr, "Usage: use this as script interpreter, execute a file starting with\n#!%s\n", argv[0]);
		exit(2);
	}

	/* Where is the current executable? */
	/* Read /proc/self/exe */
	char exe[512];
	ssize_t exesize = readlink("/proc/self/exe", exe, sizeof(exe));
	if (exesize < 0)
	{
		/* That didn't work, try argv[0] instead */
		perror("/proc/self/exe");
		strncpy(exe, argv[0], sizeof(exe));
		exesize = strlen(argv[0]);
	}
	if (exesize >= sizeof(exe))
	{
		fprintf(stderr, "Filename of executable too long.\n");
		exit(3);
	}
	/* Append NULL byte */
	exe[exesize] = 0;

	/* Strip the last component of exe to find the directory */
	char* slash = NULL;  /* Pointer to last slash in exe */
	for (int i = 0; exe[i]; ++i)
	{
		if (exe[i] == '/') slash = &(exe[i]);
	}
	if (slash) {*slash = 0;}

	/* Set the environment variable MERGER_DIR */
	setenv("MERGER_DIR", exe, 0);

	/* Add $MERGER_DIR/bin to the PATH (only if exe is an absolute path). */
	const char* path = getenv("PATH");
	if (!path) {fprintf(stderr, "No $PATH in environment\n"); exit(3);}

	if (exe[0] == '/')
	{
		char* newpath = malloc(strlen(path) + sizeof(exe) + 32);
		if (!newpath) {fprintf(stderr, "malloc failed\n"); exit(3);}
		sprintf(newpath, "%s/bin:%s", exe, path);
		path = newpath;
		setenv("PATH", path, 1);
	}

	/* Run main.sh */
	char main_sh[512];
	snprintf(main_sh, sizeof(main_sh), "%s/main.sh", exe);

	/* Arguments: "bash" "--", main_sh, argv[1],..., argv[argc-1] */
	char** newargv = calloc(argc+8, sizeof(char*));
	if (!newargv) {fprintf(stderr, "calloc failed\n"); exit(3);}
	newargv[0] = "bash";
	newargv[1] = "--";
	newargv[2] = main_sh;
	for (int i = 1; i < argc; ++i)
		newargv[2+i] = argv[i];
	execvp("bash", newargv);
	exit(127);
}
