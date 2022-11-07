/****************************************************************************\
 pl-init, v0.01
 (c) 2022 pocketlinux32, Under GPLv2 or later
 pl-init.c: Simplified clone of sysvinit
\****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

// Linux-specific headers
#include <sys/mount.h>
#include <sys/reboot.h>

void parseInitTabLine(char* line){
	char parsedLine[4][128];

	strtok()
}

int parseInitTab(){
	FILE* inittabFile = open("/etc/inittab", "r");

	if(!inittabFile){
		printf("	Could not load inittab. Running pl-srv instead");
		return 1;
	}

	char buffer[64];
	while(fgets(buffer, 64, inittabFile) != NULL){
		parseInitTabLine(buffer);
	}
}


int safeMount(char* source, char* dest, char* fstype, int mountflags, char* data){
	struct stat root;
	struct stat mountpoint;

	stat("/", &root);
	stat(dest, &mountpoint);

	printf("	%s: ", dest);
	if(mountpoint.st_dev == root.st_dev){
		if(mount(source, dest, fstype, mountflags, data) != 0){
			printf("Error.\n");
			perror("		pl-init");
			return 1;
		}else{
			printf("Successfully mounted.\n");
		}
	}else{		printf("Already mounted.\n");
	}
}

int safeMountBootFS(char* dest, char* fstype){
	return safeMount("none", dest, fstype, 0, "");
}

int main(int argc, const char* argv[]){
	pid_t pid = getpid();
	uid_t uid = getuid();

	if(uid){
		printf("Error: Init can only be ran by root\n");
		return 1;
	}

	if(pid > 1){
		printf("Error: Init can only run as PID 1\n");
		return 2;
	}

	printf("pl-init 0.01 started\n\n");
	printf("* Mounting necessary filesystems:\n");

	safeMountBootFS("/sys", "sysfs");
	safeMountBootFS("/proc", "proc");
	safeMountBootFS("/dev", "devtmpfs");

	printf("* Parsing and executing inittab:\n");
	parseInitTab();

	printf("* Executing shell\n\n");
	pid_t shell = fork();
	if(shell == 0){
		sleep(1);
		char buffer[64];
		char* args[] = { "sh", NULL };
		execv(realpath("/bin/sh", buffer), args);
	}else{
		int status;
		waitpid(shell, &status, 0);
		printf("* Shell has exited with code %d\n", status);
	}

	printf("* Powering off...\n");
	sync();
	reboot(RB_POWER_OFF);
}
