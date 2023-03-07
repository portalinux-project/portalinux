/*****************************************\
 pl-srv, v0.01
 (c) 2023 pocketlinux32, Under MPLv2.0
 pl-srv.c: Starts and supervises processes
\*****************************************/
#define _XOPEN_SOURCE
#include <pl32.h>
#include <plml.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#define PLSRV_RESPAWN 1
#define PLSRV_RUN_ONCE 2

#define PLSRV_INIT 3
#define PLSRV_HALT 4
#define PLSRV_START 5
#define PLSRV_STOP 6

typedef struct plsrv {
	string_t path;
	string_t* args;
	int type;
} plsrv_t;

void supervisorSignalHandler(int signal){
	switch(signal){
		case SIGTERM: ;
	}
}

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
	if(service == NULL)
		return -1;

	pid_t exec = 0;
	if(service->type != PLSRV_RESPAWN)
		exec = fork();

	if(exec == 0){
		if(service->type != PLSRV_RESPAWN){
			freopen("/dev/null", "w", stdin);
			freopen("/dev/null", "w", stdout);
		}

		spawnExec(service->path, service->args);
		if(service->type == PLSRV_RESPAWN){
			while(1)
				spawnExec(service->path, service->args);
		}
		exit(0);
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

		if(strcmp("exec", tokenName) == 0){
			string_t tokenVal;
			plMLGetTokenAttrib(plmlToken, &tokenVal, PLML_GET_VALUE);

			plarray_t* tokenizedVal = plParser(tokenVal, mt);
			plMTRealloc(mt, tokenizedVal->array, (tokenizedVal->size + 1) * sizeof(string_t*));
			((string_t*)tokenizedVal->array)[tokenizedVal->size] = NULL;

			returnStruct->args = tokenizedVal->array;
			returnStruct->path = ((string_t*)tokenizedVal->array)[0];

			plMTFree(mt, tokenizedVal);
		}else if(strcmp("respawn", tokenName) == 0){
			bool tokenVal;
			plMLGetTokenAttrib(plmlToken, &tokenVal, PLML_GET_VALUE);

			if(tokenVal)
				returnStruct->type = PLSRV_RESPAWN;
			else
				returnStruct->type = PLSRV_RUN_ONCE;
		}

		plMLFreeToken(plmlToken);
	}

	return returnStruct;
}

int plSrvSystemctl(int action, char* value, plmt_t* mt){
	char* fullPath = NULL;
	struct stat checkExistence;

	if(action == PLSRV_START || action == PLSRV_STOP ){
		fullPath = plMTAllocE(mt, (18 + strlen(value)) * sizeof(char));
		if(action == PLSRV_START)
			strcpy(fullPath, "/etc");
		else
			strcpy(fullPath, "/var");

		strcat(fullPath, "/pl-srv/");

		strcat(fullPath, value);
		strcat(fullPath, ".srv");
	}

	switch(action){
		case PLSRV_START: ;
			printf("* Starting service %s...\n", value);

			if(stat(fullPath, &checkExistence) == -1){
				perror("plSrvSystemctl");
				return 1;
			}

			plsrv_t* srvStruct = generateServiceStruct(fullPath, mt);
			int servicePid = executeSupervisor(srvStruct);
			if(servicePid > 0){
				strncpy(fullPath, "/var", 4);
				plfile_t* lockFile = plFOpen(fullPath, "w", mt);
				char numberBuffer[16];
				snprintf(numberBuffer, 16, "%d", servicePid);
				plFPuts(numberBuffer, lockFile);
				plFClose(lockFile);
				return 0;
			}else if(servicePid == -1){
				printf("* Error: Failed to start service %s", value);
				return 2;
			}
			break;
		case PLSRV_STOP: ;
			printf("* Stopping service %s...\n", value);

			if(stat(fullPath, &checkExistence) == -1){
				perror("plSrvSystemctl");
				return 1;
			}

			plfile_t* lockFile = plFOpen(fullPath, "r", mt);
			
			break;
		case PLSRV_INIT: ;
			DIR* directory = opendir("/etc/pl-srv");
			struct dirent* dirEntry
			plarray_t services;
			services->array = plMTAllocE(mt, 2 * sizeof(char*));
			services->size = 0;

			while((dirEntry = readdir(directory)) != NULL){
				
			}
			break;
		case PLSRV_HALT: ;
			DIR* directory = opendir("/var/pl-srv");
			break;
	}
	return 0;
}

int main(int argc, string_t argv[]){
	plmt_t* mt = plMTInit(8 * 1024 * 1024);

	if(argc > 1){
		if(strcmp("help", argv[1]) == 0){
			puts("PortaLinux Service Supervisor v0.01");
			puts("(c) 2023 pocketlinux32, Under MPLv2.0\n");
			printf("Usage: %s {options} [value]\n\n", argv[0]);
			puts("Starts and supervises a service. All service units are stored in /etc/pl-srv");
			puts("help	Shows this help");
			puts("start	Starts a service");
			puts("stop	Stops a service");
			puts("init	Starts all services");
			puts("halt	Stops all services");
			return 0;
		}else if(strcmp("init", argv[1]) == 0){
			puts("* Starting all active services...");
			plSrvSystemctl(PLSRV_INIT, argv[2], mt);
		}else if(strcmp("halt", argv[1]) == 0){
			puts("* Halting all running services...");
			plSrvSystemctl(PLSRV_HALT, argv[2], mt);
		}else if(argc > 2){
			if(strcmp("start", argv[1]) == 0){
				for(int i = 2; i < argc; i++)
					plSrvSystemctl(PLSRV_START, argv[i], mt);
			}else if(strcmp("stop", argv[1]) == 0){
				for(int i = 2; i < argc; i++)
					plSrvSystemctl(PLSRV_STOP, argv[2], mt);
			}
		}else{
			puts("Error: Not enough argument");
		}
	}else{
		puts("Error: Not enough arguments");
	}
}
