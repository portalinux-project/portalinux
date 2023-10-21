#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/kd.h>
#include <linux/keyboard.h>

#define EMBEDDED_NR_KEYS 128

char* keyPaths[3] = { "/etc/keymaps/", "/opt/share/keymaps/", "/usr/share/keymaps/" };

void printArgsError(){
	fputs("Not enough arguments\n", stderr);
	fputs("Run `plkeyb --help` for more information\n", stderr);
}

void loadKeymap(int keymapFile, int consoleFile){
	char keyFlags[MAX_NR_KEYMAPS];
	uint16_t keyValues[EMBEDDED_NR_KEYS];
	struct kbentry keyEntry;

	read(keymapFile, keyFlags, 7);
	if(strcmp(keyFlags, "bkeymap") != 0){
		fputs("Invalid keymap\n", stderr);
		exit(4);
	}

	read(keymapFile, keyFlags, MAX_NR_KEYMAPS);
	for(int i = 0; i < MAX_NR_KEYMAPS; i++){
		if(keyFlags[i] != 1)
			continue;

		read(keymapFile, keyValues, EMBEDDED_NR_KEYS * sizeof(uint16_t));
		for(int j = 0; j < EMBEDDED_NR_KEYS; j++){
			keyEntry.kb_index = j;
			keyEntry.kb_table = i;
			keyEntry.kb_value = keyValues[j];
			ioctl(consoleFile, KDSKBENT, &keyEntry);
		}
	}
}

int main(int argc, char* argv[]){
	bool keymapIsPath = false;
	char* activeKeyPath = NULL;
	char keymapName[256] = "";
	char keymapPath[1024] = "";
	int consolefd = -1;
	int keymapfd = -1;
	char junk = 0;

	if(argc < 2){
		printArgsError();
		return 1;
	}else{
		for(int i = 1; i < argc; i++){
			if(strcmp("--help", argv[i]) == 0){
				printf("PortaLinux Keyboard Tool, v0.01\n\n");
				printf("Usage: plkeyb [options] keymap\n\n");
				printf("Load a different keyboard layout\n\n");
				printf("Options:\n");
				printf("--keymapdir [/path/to/dir/]	Use path as the keymap directory\n");
				printf("--kmapispath			Treat `keymap` as a relative path\n");
				return 0;
			}else if(strcmp("--keymapdir", argv[i]) == 0){
				activeKeyPath = argv[i + 1];
				i++;
			}else if(strcmp("--kmapispath", argv[i]) == 0){
				keymapIsPath = true;
			}

			if(i == argc){
				printArgsError();
				return 1;
			}
		}

		strncpy(keymapName, argv[argc - 1], 256);
	}

	strcpy(keymapPath, "/dev/tty");
	consolefd = open(keymapPath, O_RDWR);
	if(ioctl(consolefd, KDGKBTYPE, &junk) != 0){
		close(consolefd);
		consolefd = open("/dev/console", O_RDWR);
	}

	if(keymapIsPath){
		keymapfd = open(keymapName, O_RDONLY);
	}else if(activeKeyPath != NULL){
		strncpy(keymapPath, activeKeyPath, 768);
		strcpy(keymapPath, keymapName);
		keymapfd = open(keymapPath, O_RDONLY);
	}else{
		for(int i = 0; i < 3; i++){
			strcpy(keymapPath, keyPaths[i]);
			strcpy(keymapPath + strlen(keyPaths[i]), keymapName);
			if((keymapfd = open(keymapPath, O_RDONLY)) != -1)
				i = 3;
		}
	}

	if(keymapfd == -1){
		fputs("Could not open keymap: ", stderr);
		if(activeKeyPath != NULL)
			fputs(keymapPath, stderr);
		else
			fputs(keymapName, stderr);
		fputs("\n", stderr);
		return 2;
	}

	if(consolefd == -1 || ioctl(consolefd, KDGKBTYPE, &junk) != 0){
		fputs("Could not open console\n", stderr);
		return 2;
	}

	loadKeymap(keymapfd, consolefd);

	close(consolefd);
	close(keymapfd);
}
