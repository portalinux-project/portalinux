/*****************************************\
 pl-srv, v0.01
 (c) 2023 pocketlinux32, Under MPLv2.0
 pl-srv.c: Starts and supervises processes
\*****************************************/
#define _XOPEN_SOURCE 700
#include <pl32.h>
#include <plml.h>
#include <dirent.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#define PLSRV_INIT 10
#define PLSRV_HALT 11
#define PLSRV_START 12
#define PLSRV_STOP 13

pid_t activePid = 0;

typedef struct plsrv {
	string_t path;
	string_t* args;
	bool respawn;
	bool background;
} plsrv_t;

void supervisorSignalHandler(int signal){
	switch(signal){
		case SIGTERM: ;
		case SIGINT: ;
			kill(activePid, SIGTERM);
			break;
	}
	exit(0);
}

void setSignal(int signal, struct sigaction* newHandler){
	struct sigaction oldHandler;
	sigaction(signal, NULL, &oldHandler);
	if(oldHandler.sa_handler != SIG_IGN)
		sigaction(signal, newHandler, NULL);
}

int spawnExec(string_t path, string_t* args){
	pid_t exec = fork();
	int status;
	if(exec == 0){
		sleep(1);
		char buffer[256];
		execv(realpath(path, buffer), args);

		perror("execv");
		return 255;
	}else{
		activePid = exec;
		waitpid(exec, &status, 0);
	}
	return status;
}

int executeSupervisor(plsrv_t* service){
	if(service == NULL)
		return -1;

	pid_t exec = 0;
	if(service->respawn == true || service->background == true)
		exec = fork();

	if(exec == 0){
		if(service->background == true){
			freopen("/dev/null", "w", stdin);
			freopen("/dev/null", "w", stdout);
		}

		struct sigaction newSigAction;
		newSigAction.sa_handler = supervisorSignalHandler;
		sigemptyset(&newSigAction.sa_mask);
		newSigAction.sa_flags = 0;
		setSignal(SIGTERM, &newSigAction);
		setSignal(SIGINT, &newSigAction);

		spawnExec(service->path, service->args);
		if(service->respawn == true){
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
	returnStruct->respawn = false;
	returnStruct->background = false;

	if(srvFile == NULL)
		return NULL;

	byte_t buffer[256] = "";
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
			bool* tokenVal;
			plMLGetTokenAttrib(plmlToken, &tokenVal, PLML_GET_VALUE);
			returnStruct->respawn = *tokenVal;
		}else if(strcmp("background", tokenName) == 0){
			bool* tokenVal;
			plMLGetTokenAttrib(plmlToken, &tokenVal, PLML_GET_VALUE);
			returnStruct->background = *tokenVal;
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
			char numBuffer[16] = "";
			char* pointerHolder;
			pid_t pidNum;
			plFGets(numBuffer, 16, lockFile);
			pidNum = strtol(numBuffer, &pointerHolder, 10);
			kill(pidNum, SIGTERM);
			plFClose(lockFile);
			remove(fullPath);
			break;
		case PLSRV_INIT: ;
			DIR* directorySrv = opendir("/etc/pl-srv");
			struct dirent* dirEntriesSrv;

			if(directorySrv == NULL){
				puts("Error: Service directory not found");
				return 3;
			}

			readdir(directorySrv);
			readdir(directorySrv);
			while((dirEntriesSrv = readdir(directorySrv)) != NULL){
				plSrvSystemctl(PLSRV_START, strtok(dirEntriesSrv->d_name, "."), mt);
			}
			break;
		case PLSRV_HALT: ;
			DIR* directoryActive = opendir("/var/pl-srv");
			struct dirent* dirEntriesActive;

			if(directorySrv == NULL){
				puts("Error: Service directory not found");
				return 3;
			}

			readdir(directorySrv);
			readdir(directorySrv);
			while((dirEntriesActive = readdir(directoryActive)) != NULL){
				plSrvSystemctl(PLSRV_STOP, dirEntriesActive->d_name, mt);
			}
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
