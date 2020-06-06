/* Kill the whole current process group */

#include <unistd.h>
#include <signal.h>
int main()
{
    kill(-getpgrp(), SIGHUP);
}
