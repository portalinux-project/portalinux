/******************************************************\
 pl-srv, v0.01
 (c) 2023 pocketlinux32, Under MPLv2.0
 pl-init.c: Initializes the system enough to run pl-srv
\******************************************************/
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

	fputs(stdout, "* Force-killing all processes...");
	kill(-1, SIGKILL);
	puts("Done.");

	fputs(stdout, "* Syncing cached file ops...");
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

int safeMount(string_t source, string_t dest, string_t fstype, int mountflags, string_t data){
	struct stat root;
	struct stat mountpoint;

	stat("/", &root);
	stat(dest, &mountpoint);

	fputs(stdout, "	%s:", dest); // That is a tab, not a space
	if(mountpoint.st_dev == root.st_dev){
		if(mount(source, dest, fstype, mountflags, data) != 0){
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

int safeMountBootFS(string_t dest, string_t fstype){
	return safeMount("none", dest, fstype, 0, "");
}

int main(int argc, string_t argv[]){
	pid_t pid = getpid();
	uid_t uid = getuid();

	// Argument parsing
	if(argc > 1){
		puts("PortaLinux Init v0.01\n");
		for(int i = 1; i < argc; i++){
			if(strcmp(argv[i], "--help") == 0){
				puts("(c) 2023 pocketlinux32, Under MPLv2.0\n");
				printf("Usage: %s [options]\n\n", argv[0]);
				puts("Initializes a PortaLinux System enough to run the pl-srv process supervisor.")
				puts("When ran in normal mode, it must be ran as PID 1 and by root");
				puts("--help		Shows this help");
				puts("--chroot		Run in chroot mode");
				return 0;
			}else if(strcmp(argv[i], "--chroot")){
				puts("* Running in chroot mode!");
				inChroot = true;
			}
		}
	}

	// Simple Initialization
	if(inChroot){
		puts("Bypassing initialization and dropping you to a shell...");
		string_t args[2] = { "sh", NULL };
		execv("/bin/sh", args);
	}else{
		puts("* Mounting necessary filesystems:");
		safeMountBootFS("/sys", "sysfs");
		safeMountBootFS("/proc", "proc");
		safeMountBootFS("/dev", "devtmpfs");

		fputs(stdout, "* Enabling signal handler: ");
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
		string_t plSrvArgs[3] = { "pl-srv", "init", NULL };
		spawnExec("/usr/bin/pl-srv", plSrvArgs);
		while(1);
	}

	signalHandler(SIGTERM);
}
