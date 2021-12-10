#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#define SLEEP_FOR 5

int main(void) {
    pid_t child_pid[2];
    int pid;

    printf("parent pid: %d, group: %d\n", getpid(), getpgrp());
    for (int i = 0; i < 2; i++) {
        pid = fork();
        if (pid == -1) {
            perror("cant fork\n");
            return EXIT_FAILURE;
        } else if (pid == 0) {
            sleep(SLEEP_FOR);
            printf("child pid: %d, group %d, ppid: %d\n", getpid(), getpgrp(), getppid());
            return EXIT_SUCCESS;
        } else {
            child_pid[i] = pid;
        }
    }
    printf("parent pid: %d\nchildren %d %d\n", getpid(), child_pid[0], child_pid[1]);
    printf("parent dead\n");
    return EXIT_SUCCESS;
}