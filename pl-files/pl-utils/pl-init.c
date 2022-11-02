/****************************************************************************\
 pl-init, v0.01
 (c) 2022 pocketlinux32, Under GPLv2 or later
 pl-init.c: Simplified init
\****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, const char* argv[]){
	pid_t pid = getpid();
	uid_t uid = getuid();

	if(pid){
		printf("Error: Init can only run as PID 1\n");
		return 1;
	}

	
}
