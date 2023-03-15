/******************************************************\
 pl-srv, v0.01
 (c) 2023 pocketlinux32, Under MPLv2.0
 pl-init.c: Initializes the system enough to run pl-srv
\******************************************************/
#define _XOPEN_SOURCE
#include <pl32.h>
#include <signal.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

// Linux-specific headers
#include <sys/mount.h>
#include <sys/reboot.h>

bool inChroot = false;

int spawnExec(string_t path, string_t* args){
	pid_t exec = fork();
	int status;
	if(exec == 0){
		sleep(1);
		char buffer[256];
		execv(realpath(path, buffer), args);

		perror("execv");
		exit(1);
	}else{
		waitpid(exec, &status, 0);
	}
	return status;
}

void signalHandler(int signal){
	string_t plSrvArgs[3] = { "pl-srv", "halt", NULL };
	spawnExec("/usr/bin/pl-srv", plSrvArgs);

	fputs("* Force-killing all processes...", stdout);
	kill(-1, SIGKILL);
	puts("Done.");

	fputs("* Syncing cached file ops...", stdout);
	sync();
	puts("Done.");

	switch(signal){
		case SIGTERM: ;
			puts("* Rebooting...");
			reboot(RB_AUTOBOOT);
		case SIGINT: ;
		case SIGUSR1: ;
			puts("* Halting system...");
			reboot(RB_HALT_SYSTEM);
		case SIGPWR: ;
		case SIGUSR2: ;
			puts("* Powering off...");
			reboot(RB_POWER_OFF);
	}
}

void setSignal(int signal, struct sigaction* newHandler){
	struct sigaction oldHandler;
	sigaction(signal, NULL, &oldHandler);
	if(oldHandler.sa_handler != SIG_IGN)
		sigaction(signal, newHandler, NULL);
}

int safeMountBoot(string_t dest, string_t fstype){
	struct stat root;
	struct stat mountpoint;

	stat("/", &root);
	stat(dest, &mountpoint);

	printf("	%s:", dest);
	if(mountpoint.st_dev == root.st_dev){
		if(mount("none", dest, fstype, 0, "") != 0){
			puts("Error.");
			perror("		pl-init");
			return 1;
		}else{
			puts("Successfully mounted.");
		}
	}else{
		puts("Already mounted.");
	}
	return 0;
}

int main(int argc, string_t argv[]){
	pid_t pid = getpid();
	uid_t uid = getuid();
	puts("PortaLinux Init v0.01");
	puts("(c) 2023 pocketlinux32, Under MPLv2.0\n");

	// Argument parsing
	if(argc > 1){
		for(int i = 1; i < argc; i++){
			if(strcmp(argv[i], "--help") == 0){
				printf("Usage: %s [options]\n\n", argv[0]);
				puts("Initializes a PortaLinux System enough to run the pl-srv process supervisor.");
				puts("When ran in normal mode, it must be ran as PID 1 and by root");
				puts("--help		Shows this help");
				puts("--chroot		Run in chroot mode");
				return 0;
			}else if(strcmp(argv[i], "--chroot") == 0){
				puts("* Running in chroot mode!");
				inChroot = true;
			}
		}
	}

	if(uid != 0){
		puts("Error: Only root can run init");
		return 1;
	}

	// Simple Initialization
	if(inChroot){
		puts("Bypassing initialization and dropping you to a shell...");
		string_t args[2] = { "sh", NULL };
		execv("/bin/sh", args);
	}else{
		if(pid != 1){
			puts("Error: Init must be ran as PID 1");
			return 2;
		}

		puts("* Mounting necessary filesystems:");
		safeMountBoot("/sys", "sysfs");
		safeMountBoot("/proc", "proc");
		safeMountBoot("/dev", "devtmpfs");

		fputs("* Enabling signal handler: ", stdout);
		struct sigaction newSigAction;
		newSigAction.sa_handler = signalHandler;
		sigemptyset(&newSigAction.sa_mask);
		newSigAction.sa_flags = 0;

		setSignal(SIGPWR, &newSigAction);
		setSignal(SIGTERM, &newSigAction);
		setSignal(SIGINT, &newSigAction);
		setSignal(SIGUSR1, &newSigAction);
		setSignal(SIGUSR2, &newSigAction);
		puts("Done.");

		puts("* Running pl-srv...\n");
		string_t plSrvArgs[5] = { "pl-srv", "init", NULL };
		spawnExec("/usr/bin/pl-srv", plSrvArgs);
		while(1);
	}

	signalHandler(SIGTERM);
}
