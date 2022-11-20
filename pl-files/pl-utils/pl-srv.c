/***************************************************************************\
 pl-init, v0.01
 (c) 2022 pocketlinux32, Under GPLv2 or later
 pl-srv.c: Simplified implementation of rust-based pl-srv service supervisor
\***************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <sys/type.h>

#define PL_WAIT 0
#define PL_RESPAWN 1

typedef struct plexec {
	char* path;
	char** args;
	int action;
	bool silent;
} plexec_t;

pid_t spawnExec(plexec_t executable){
	pid_t exec = fork();
	int status;
	if(exec == 0){
		sleep(1);
		char buffer[256];
		if(silent){
			fclose(stdout);
			fclose(stderr);
		}
		execv(realpath(executable.path, buffer), executable.args);
	}else{
		if(executable.action == PL_WAIT){
			waitpid(exec, &status, 0);
			return status;
		}else if(executable.action == PL_RESPAWN){
			return exec;
		}
	}
}

int startTask(char* name){
	char fullPath[256] = "/etc/pl-srv/";
	strncat(fullPath, name, 239);
	strcat(fullPath, ".srv");

	FILE* serviceUnit = fopen(fullPath, "r");

	if(!serviceUnit){
		printf("Error: Unit %s does not exist", fullPath);
		return 1;
	}

	//TODO: add service unit parser
}

int stopTask(char* name){
	
}

void initSystem(char* target){
	
}

void stopSystem(void){
	
}

int main(int argc, const char* argv[]){
	if(argv > 1){
		for(int i = 0; i < argc; i++){
			if(){
				
			}
		}
	}
}
