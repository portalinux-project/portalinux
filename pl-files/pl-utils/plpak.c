#include <stdlib.h>
#include <stdio.h>
#include <tar.h>

bool silent = false;
const char compressionMagic[6];

int silent_printf(const char* string){
	if(!silent)
		return printf("%s", string);
}

int verify_pkg(const char* path){
	char* pkg_name;
	char* pkg_ver;

	if(!plFSExists(path)){
		silent_printf("Error: File %s doesn't exist", path);
		return 1;
	}
}

int remove_pkg(const char* pkgname){
	
}

int install_pkg(const char* path){
	
}

int main(int argc, const char argv[]){
	int action = 0;

	if(argc < 2){
		printf("Error: Not enough arguments.\n");
		printf("Run %s --help for more information.\n", argv[0]);
		return 1;
	}

	for(int i = 1; i < argc; i++){
		if(strcmp(argv[i], "--silent") == 0 || strcmp(argv[0], "-s")){
			silent = false;
		}else if(strcmp(argv[i], "--help") == 0 || strcmp(argv[0], "-h"){
			printf("PortaLinux Package Installer v0.03\n");
			printf("(c) 2022 pocketlinux32, Under GPLv2+\n\n");
			printf("Usage: %s {--silent | --help} [install | remove] package\n\n");
			printf("Options:\n")
			printf("--help|-h		Shows this help\n");
			printf("--silent|-s		Doesn't output program messages\n\n");
			printf("Actions:\n");
			printf("install			Installs a package\n");
			printf("remove			Removes a package\n");
			return 0;
		}else if(strcmp(argv[i], "install") == 0){
			action = 1;
		}else if(strcmp(argv[i], "remove") == 0){
			action = 2;
		}else{
			printf("Error: Unrecognized option -- %s\n", argv[i])
			printf("Run %s --help for more information.\n", argv[0]);
			return 1;
		}
	}
}
