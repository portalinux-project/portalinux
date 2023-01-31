/*****************************************\
 pl-srv, v0.01
 (c) 2023 pocketlinux32, Under MPLv2.0
 pl-srv.c: Starts and supervises processes
\*****************************************/
#include <pl32.h>
#include <plml.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#define PLSRV_RESPAWN 1
#define PLSRV_RUN_ONCE 2

struct plsrv {
	char* path;
	char** args;
	int type;
}; plsrv_t;

int spawnExec(char* path, char** args){
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

int executeSupervisor(plsrv_t* service){
	
}

int main(int argc, char* argv[]){

}
