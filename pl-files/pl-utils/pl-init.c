/****************************************************************************\
 pl-init, v0.01
 (c) 2022 pocketlinux32, Under GPLv2 or later
 pl-init.c: Simplified clone of sysvinit
\****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

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

	printf("* Executing shell\n\n");
	pid_t shell = fork();
	if(shell == 0){
		sleep(1);
		execl("/bin/toybox", "/bin/sh", NULL);
	}else{
		int status;
		waitpid(shell, &status, 0);
		printf("* Shell has exited with code %d\n", status);
	}

	while(1);
}
