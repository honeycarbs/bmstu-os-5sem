#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

char *msgs[2] = {"aksjdo", "lasjdoajsdoi"};

int main(void) {
    pid_t child_pid[2];
    int fd[2];
    int pid;
    int status;
    int child;
    char buf[100] = {0};

    printf("parent pid: %d, group: %d\n", getpid(), getpgrp());
    if (pipe(fd) == -1) {
        perror("cant pipe\n");
        return EXIT_FAILURE;
    }
    for (int i = 0; i < 2; i++) {
        pid = fork();
        if (pid == -1) {
            perror("cant fork\n");
            return EXIT_FAILURE;
        } else if (pid == 0) {
            close(fd[0]);
            write(fd[1], msgs[i], strlen(msgs[i]));
            printf("msg from child (pid = %d) %s sent to parent\n", getpid(), msgs[i]);
            return EXIT_SUCCESS;
        } else {
            child_pid[i] = pid;
        }
    }
    for (int i = 0; i < 2; i++) {
        child = wait(&status);
        printf("child finished\nchild pid: %d, status: %d\n", child, status);
        if (WIFEXITED(status)) {
            printf("child exited with code %d\n", WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            printf("child terminated with un-intercepted signal number %d\n", WTERMSIG(status));
        } else if (WIFSTOPPED(status)) {
            printf("child stopped with signal number %d\n", WSTOPSIG(status));
        }
    }
    close(fd[1]);
    read(fd[0], buf, sizeof(buf));
    printf("parent (pid: %d) recieved msgs: %s\n", getpid(), buf);
    printf("parent pid: %d\nchildren %d %d\n", getpid(), child_pid[0], child_pid[1]);
    printf("parent dead\n");
    return EXIT_SUCCESS;
}