#include <sys/types.h>
#include <unistd.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char** argv)
{
	struct passwd* pwd;
	pwd = getpwuid(getuid());
	if (!pwd) {perror("getpwuid"); exit(1);}

	const char* p;
	for (p = pwd->pw_gecos; *p && (*p != ','); ++p)
	{
		putchar(*p);
	}
	putchar('\n');

	return 0;
}
