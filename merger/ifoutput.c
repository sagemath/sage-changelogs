/*
 * ifoutput: Run a shell command and check whether output is
 * produced, running an optional pre-command if yes.
 * Copyright (C) 2011  Jeroen Demeyer <jdemeyer@cage.ugent.be>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/wait.h>

/* A structure defined to "pump" data: read from rfd and immediately
 * write to wfd. */
typedef struct
{
	int rfd;  /* Set to -1 upon error or EOF */
	int wfd;  /* Set to -1 upon error */
	int readable;   /* 1 if pselect says we can read */
	int writable;   /* 1 if pselect says we can write */
} pump_t;

/* How many bytes to pump at a time */
#define BUFFERSIZE 4096


/* Signal handler */
volatile int got_chld = 0;
void handle_chld(int signum)
{
	got_chld = 1;
}

int main(int argc, char** argv)
{
	/* There should be either 1 or 2 command line arguments */
	if (argc < 2 || argc > 3)
	{
		fprintf(stderr,
			"Usage: %s [PRE-COMMAND] COMMAND\n"
			"Run COMMAND. If output is produced (either stdout or stderr), run\n"
			"PRE-COMMAND before displaying output.\n"
			"Return 0 if there was output, 1 if no output.\n", argv[0]);
		exit(2);
	}

	const char *precmd = NULL;
	const char *cmd = "";
	int got_output = 0;

	if (argc == 2)
	{
		cmd = argv[1];
	}
	else
	{
		precmd = argv[1];
		cmd = argv[2];
	}

	/* SIGCHLD handler */
	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = handle_chld;
	if (sigaction(SIGCHLD, &sa, NULL)) {perror("sigaction"); exit(1);}

	/* Block SIGCHLD for pselect() */
	sigset_t defaultmask;
	sigset_t blockmask;
	sigemptyset(&blockmask);
	sigaddset(&blockmask, SIGCHLD);
	if (sigprocmask(SIG_BLOCK, &blockmask, &defaultmask)) {perror("sigprocmask"); exit(1);}

	/* Pipes for stdout and stderr */
	int stdoutpipe[2];
	int stderrpipe[2];
	if (pipe(stdoutpipe)) {perror("pipe"); exit(1);}
	if (pipe(stderrpipe)) {perror("pipe"); exit(1);}

	pid_t child = fork();
	if (child < 0) {perror("fork"); exit(1);}
	if (child == 0)
	{
		/* CHILD: execute COMMAND */
		signal(SIGCHLD, SIG_DFL);
		sigprocmask(SIG_SETMASK, &defaultmask, NULL);
		dup2(stdoutpipe[1], 1);
		dup2(stderrpipe[1], 2);
		close(stdoutpipe[0]);
		close(stderrpipe[0]);
		close(stdoutpipe[1]);
		close(stderrpipe[1]);
		execl("/bin/sh", "sh", "-c", cmd, NULL);
		perror("/bin/sh");
		exit(1);
	}

	close(stdoutpipe[1]);
	close(stderrpipe[1]);

	/* Define pumps */
	pump_t pump[3];
	memset(pump, 0, sizeof(pump));

	pump[0].rfd = stdoutpipe[0];
	pump[0].wfd = 1;
	pump[1].rfd = stderrpipe[0];
	pump[1].wfd = 2;
	int npump = 2;

	/* Main select loop */
	int i;
	fd_set readfds;
	fd_set writefds;
	int nfds;
	struct timespec tv;

	char buffer[BUFFERSIZE];
	for (;;)
	{
		if (got_chld)
		{
			got_chld = 0;
			int status;
			if (waitpid(child, &status, WNOHANG) == child)
			{
				exit(got_output ? 0 : 1);
			}
		}

		/* File descriptors to check for pselect() */
		FD_ZERO(&readfds);
		FD_ZERO(&writefds);
		nfds = 0;
		for (i = 0; i < npump; i++)
		{
			if (pump[i].rfd >= 0 && !pump[i].readable)
			{
				FD_SET(pump[i].rfd, &readfds);
				if (pump[i].rfd >= nfds) nfds = pump[i].rfd+1;
			}
			if (pump[i].wfd >= 0 && !pump[i].writable)
			{
				FD_SET(pump[i].wfd, &writefds);
				if (pump[i].wfd >= nfds) nfds = pump[i].wfd+1;
			}
		}

		/* Select with 20 second timeout */
		tv.tv_sec = 20;
		tv.tv_nsec = 0;
		int sel = pselect(nfds, &readfds, &writefds, NULL, &tv, &defaultmask);

		/* Error or interrupt */
		if (sel < 0)
		{
			if (errno != EINTR) {perror("pselect"); exit(1);}
			continue;
		}

		/* Timeout: check child just in case... */
		if (sel == 0) {got_chld = 1; continue;}

		/* Check file descriptors and pump data */
		for (i = 0; i < npump; i++)
		{
			if (pump[i].rfd >= 0 && FD_ISSET(pump[i].rfd, &readfds)) pump[i].readable = 1;
			if (pump[i].wfd >= 0 && FD_ISSET(pump[i].wfd, &writefds)) pump[i].writable = 1;
			if (pump[i].readable && pump[i].writable)
			{
				/* Force a new pselect() call before reading again */
				pump[i].readable = 0;

				ssize_t s = read(pump[i].rfd, buffer, BUFFERSIZE);
				if (s <= 0)  /* Error or EOF */
				{
					if (s < 0) perror("read");
					close(pump[i].rfd);
					pump[i].rfd = -1;
				}
				else  /* Read something */
				{
					if (precmd)
					{
						/* Execute precmd */
						pid_t child2 = fork();
						if (child2 < 0) {perror("fork"); exit(1);}
						if (child2 == 0)
						{
							signal(SIGCHLD, SIG_DFL);
							sigprocmask(SIG_SETMASK, &defaultmask, NULL);
							for (i = 0; i < npump; i++)
								if (pump[i].rfd >= 0) close(pump[i].rfd);
							execl("/bin/sh", "sh", "-c", precmd, NULL);
							perror("/bin/sh");
							exit(1);
						}
						while (waitpid(child2, NULL, 0) != child2) {}
						precmd = NULL;
					}
					got_output = 1;
					pump[i].writable = 0;
					if (write(pump[i].wfd, buffer, s) != s)
					{
						/* Error */
						pump[i].wfd = -1;
					}
				}
			}
		}
	}
}
