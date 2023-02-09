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
	string_t path;
	string_t* args;
	int type;
}; plsrv_t;

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

int executeSupervisor(plsrv_t* service){
	pid_t exec = fork();
	if(exec == 0){
		fclose(stdin);
		freopen("/dev/null", "w", stdout);
		spawnExec(service->path, service->args);
		if(service->type == PLSRV_RESPAWN){
			while(1)
				spawnExec(service->path, service->args);
		}
	}

	return exec;
}

plsrv_t* generateServiceStruct(string_t pathname, plmt_t* mt){
	if(pathname == NULL || mt == NULL)
		return NULL;

	plfile_t* srvFile = plFOpen(pathname, "r", mt);
	plsrv_t* returnStruct = plMTAllocE(mt, sizeof(plsrv_t));

	if(srvFile == NULL)
		return NULL;

	byte_t buffer[256];
	while(plFGets(buffer, 256, srvFile) != NULL){
		plmltoken_t* plmlToken = plMLParse(buffer, mt);
		string_t tokenName;

		plMLGetTokenAttrib(plmlToken, &tokenName, PLML_GET_NAME);

		if(strcmp("execPath", tokenName) == 0){
			string_t tokenVal;
			size_t tokenValLen;
			plMLGetTokenAttrib(plmlToken, &tokenVal, PLML_GET_VALUE);
			tokenValLen = strlen(tokenVal) + 1;

			returnStruct->path = plMTAllocE(mt, tokenValLen);
			memcpy(returnStruct->path, tokenVal, tokenValLen);
		}

		plMLFreeToken(plmlToken);
	}
}

int main(int argc, string_t argv[]){

}
