/****************************************************************************\
 pl-init, v0.02
 (c) 2022 pocketlinux32, Under GPLv2 or later
 pl-init.c: Simplified clone of sysvinit
\****************************************************************************/

#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

// Linux-specific headers
#include <sys/mount.h>
#include <sys/reboot.h>

typedef struct plexec {
	char* path;
	char** args;
	bool respawn;
} plexec_t;

plexec_t* execBuffer;

void signalHandler(int signal){
	free(execBuffer);

	printf("* Syncing cached file ops...\n");
	sync();

	switch(signal){
		case SIGTERM: ;
			printf("* Rebooting...\n");
			reboot(RB_AUTOBOOT);
		case SIGINT: ;
		case SIGUSR1: ;
			printf("* Halting system...\n");
			reboot(RB_HALT_SYSTEM);
		case SIGPWR: ;
		case SIGUSR2: ;
			printf("* Powering off...\n");
			reboot(RB_POWER_OFF);
	}
}

void setSignal(int signal, struct sigaction* newHandler){
	struct sigaction oldHandler;
	sigaction(signal, NULL, &oldHandler);
	if(oldHandler.sa_handler != SIG_IGN)
		sigaction(signal, newHandler, NULL);
}

int spawnExec(plexec_t executable){
	pid_t exec = fork();
	int status;
	if(exec == 0){
		sleep(1);
		char buffer[256];
		execv(realpath(executable.path, buffer), executable.args);
	}else{
		waitpid(exec, &status, 0);
	}
	return status;
}

#ifndef PL_SRV_INIT
void respawnExec(plexec_t executable){
	while(1){
		spawnExec(executable);
	}
}

void parseInitTabLine(char* line){
	char token[4][512];
	char* stringHolder;

	// TODO: add proper line parser here
	int i = 1;
	stringHolder = strtok(line, ":");
	strcpy(token[0], stringHolder);
	while((stringHolder = strtok(NULL, ":")) != NULL && i < 4){
		strcpy(token[i], stringHolder);
	}
}

int parseInitTab(){
	FILE* inittabFile = NULL; //fopen("/etc/inittab", "r");

	if(!inittabFile){
		printf("	Could not load inittab. Running defaults instead");
		return 1;
	}

	int amnt = 0;
	char buffer[512];
	while(fgets(buffer, 512, inittabFile) != NULL){
		parseInitTabLine(buffer);
	}

	return 0;
}
#endif

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
	}else{
		printf("Already mounted.\n");
	}
	return 0;
}

int safeMountBootFS(char* dest, char* fstype){
	return safeMount("none", dest, fstype, 0, "");
}

int main(int argc, const char* argv[]){
	pid_t pid = getpid();
	uid_t uid = getuid();

	if(argc > 1){
		printf("pl-init v0.02\n");
		printf("(c) 2022 pocketlinux32, Under GPLv2 or later\n\n");
		printf("Usage: %s\n\n", argv[0]);
		printf("Initializes a PortaLinux system. Must be ran as PID 1.\n");
		printf("Depending on the compilation options, it might have a dependency to pl-srv\n");
		#ifdef PL_SRV_INIT
		printf("NOTE: This version of pl-init was compiled with a pl-srv dependency\n");
		#endif
		return 0;
	}

	if(uid){
		printf("Error: Init can only be ran by root\n");
		return 1;
	}

	if(pid > 1){
		printf("Error: Init can only run as PID 1\n");
		return 2;
	}

	printf("pl-init 0.02 started\n\n");
	printf("* Mounting necessary filesystems:\n");

	safeMountBootFS("/sys", "sysfs");
	safeMountBootFS("/proc", "proc");
	safeMountBootFS("/dev", "devtmpfs");

	struct sigaction newSigAction;
	newSigAction.sa_handler = signalHandler;
	sigemptyset(&newSigAction.sa_mask);
	newSigAction.sa_flags = 0;

	setSignal(SIGPWR, &newSigAction);
	setSignal(SIGTERM, &newSigAction);
	setSignal(SIGINT, &newSigAction);
	setSignal(SIGUSR1, &newSigAction);
	setSignal(SIGUSR2, &newSigAction);

	#ifndef PL_SRV_INIT
	printf("* Parsing inittab:");
	if(parseInitTab()){
		execBuffer = malloc(3 * sizeof(plexec_t));
		char* sysinit[3] = { "pl-srv", "init", NULL };
		char* respawn[2] = { "sh", NULL };

		execBuffer[0].path = "/usr/bin/pl-srv";
		execBuffer[0].args = sysinit;
		execBuffer[0].respawn = false;
		execBuffer[1].path = "/bin/sh";
		execBuffer[1].args = respawn;
		execBuffer[1].respawn = true;
		execBuffer[2].path = NULL;
	}

	int i = 0;
	while(execBuffer[i].path != NULL){
		if(execBuffer[i].respawn){
			pid_t status = fork();
			if(status == 0){
				respawnExec(execBuffer[i]);
			}
		}else{
			spawnExec(execBuffer[i]);
		}
	}
	#else
	printf("* Running pl-srv...");
	plexec_t plsrv;
	char* plsrvargs[3] = { "pl-srv", "init", NULL };
	plsrv.path = "/usr/bin/pl-srv";
	plsrv.args = plsrvargs;
	spawnExec(plsrv);
	#endif

	return 3;
}
