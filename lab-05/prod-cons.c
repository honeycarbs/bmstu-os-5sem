#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <wait.h>

#define BIN_SEM 0
#define BUF_FULL 1
#define BUF_EMPTY 2

#define P -1  // пропустить
#define V 1   // освободить

#define FREE 1
#define N 64

#define CNUM 3
#define PNUM 3
#define SNUM 3

#define RUNS 9

#define CTIME_FROM 1
#define CTOME_RANGE 4

#define PTIME_FROM 1
#define PTIME_RANGE 2

#define PERMS S_IRWXU | S_IRWXG | S_IRWXO
#define KEY IPC_PRIVATE

typedef struct c_buf {
  size_t r_pos;
  size_t w_pos;
  char data[N]
} c_buf_t;

struct sembuf PRODUCE_LOCK[2] = {
    {BUF_EMPTY, P, 0},  // Ожидает освобождения хотя бы одной ячейки буфера
    {BIN_SEM, P, 0}  // Ожидает, пока другой производитель или потребитель
                     // выйдет из критической зоны
};

struct sembuf PRODUCE_RELEASE[2] = {
    {BUF_FULL, V, 0},  // Увеличивает кол-во заполненных ячеек
    {BIN_SEM, V, 0}  // Освобождает критическую зону
};

struct sembuf CONSUME_LOCK[2] = {
    {BUF_FULL, P,
     0},  // Ожидает, что будет заполнена хотя бы одна ячейка буфера
    {BIN_SEM, P, 0}  // Ожидает, пока другой производитель или потребитель
                     // выйдет из критической зоны
};

struct sembuf CONSUME_RELEASE[2] = {
    {BUF_EMPTY, V, 0},  // Увеличивает кол-во пустых ячеек
    {BIN_SEM, V, 0}  // Освобождает критическую зону
};

int bfrInit(c_buf_t *const bufr) {
  if (!bufr) {
    return -1;
  }
  memset(bufr, 0, sizeof(c_buf_t));
  return 0;
}

int bfrWrite(c_buf_t *const bufr, const char val) {
  if (!bufr) {
    return -1;
  }
  bufr->data[bufr->w_pos++] = val;
  bufr->w_pos %= N;
  return 0;
}

int bfrRead(c_buf_t *const bufr, char *const dest) {
  if (!bufr) {
    return -1;
  }
  *dest = bufr->data[bufr->r_pos++];
  bufr->r_pos %= N;
  return 0;
}

int producerRoutine(c_buf_t *const bufr, const int sem_id, const int prod_id) {
  if (!bufr) {
    return -1;
  }
  srand(time(NULL) + prod_id);
  int sinterv;
  char symb;

  for (int i = 0; i < RUNS; i++) {
    sinterv = rand() % PTIME_RANGE + PTIME_FROM;
    sleep(sinterv);

    if (semop(sem_id, PRODUCE_LOCK, 2) == -1) {
      perror("can't semop.");
      exit(-1);
    }
    // enter CS
    symb = 'a' + (char)(bufr->w_pos % 26);
    if (bfrWrite(bufr, symb) == -1) {
      perror("can't write to buffer.");
      return -1;
    }
    printf("\e[1;32mproducer #%d ->\t %c\e[0m (slept for %ds)\n", prod_id,
           symb, sinterv);
    // exit CS
    if (semop(sem_id, PRODUCE_RELEASE, 2) == 1) {
      perror("can't semop.");
      exit(-1);
    }
  }
  return 0;
}

int consumerRoutine(c_buf_t *const bufr, const int sem_id, const int cons_id) {
  if (!bufr) {
    return -1;
  }
  srand(time(NULL) + cons_id + CNUM);
  int sinterv;
  char symb;

  for (int i = 0; i < RUNS; i++) {
    sinterv = rand() % CTOME_RANGE + CTIME_FROM;
    sleep(sinterv);

    if (semop(sem_id, CONSUME_LOCK, 2) == -1) {
      perror("can't semop.");
      exit(-1);
    }
    // enter CS
    if (bfrRead(bufr, &symb) == -1) {
      perror("can't read from buffer.");
      exit(-1);
    }
    printf("\e[1;31mconsumer #%d ->\t %c\e[0m (slept for %ds)\n", cons_id, symb,
           sinterv);
    // exit CS
    if (semop(sem_id, CONSUME_RELEASE, 2) == -1) {
      perror("can't semop.");
      exit(-1);
    }
  }
  return 0;
}

int main() {
  setbuf(stdout, NULL);
  int fdscr = shmget(KEY, sizeof(c_buf_t), IPC_CREAT | PERMS);
  if (fdscr == -1) {
    perror("can't shmget.");
    return -1;
  }

  c_buf_t *bfr;
  if ((bfr = (c_buf_t *)shmat(fdscr, 0, 0)) == (void *)-1) {
    perror("can't shmat.");
    return -1;
  }

  if (bfrInit(bfr) == -1) {
    perror("can't init buffer.");
    return -1;
  }

  int sem_id = semget(KEY, SNUM, IPC_CREAT | PERMS);
  if (sem_id == -1) {
    perror("can't semget.");
    return -1;
  }
  semctl(sem_id, BIN_SEM, SETVAL, FREE);
  semctl(sem_id, BUF_EMPTY, SETVAL, N);
  semctl(sem_id, BUF_FULL, SETVAL, 0);

  pid_t chpid;
  for (int i = 0; i < PNUM; i++) {
    switch (chpid = fork()) {
      case -1:
        perror("can't fork producer.");
        exit(-1);
        break;
      case 0:
        producerRoutine(bfr, sem_id, i);
        return 0;
    }
  }

  for (int i = 0; i < CNUM; i++) {
    switch (chpid = fork()) {
      case -1:
        perror("can't fork consumer.");
        exit(-1);
        break;
      case 0:
        consumerRoutine(bfr, sem_id, i);
        return 0;
    }
  }

  for (size_t i = 0; i < CNUM + PNUM; i++) {
    int status;
    if (wait(&status) == -1) {
      perror("wait failed.");
      exit(-1);
    }
    if (!WIFEXITED(status)) printf("one of children terminated abnormally\n");
  }

  if (shmdt((void *)bfr) == -1 || shmctl(fdscr, IPC_RMID, NULL) == -1 ||
      semctl(sem_id, IPC_RMID, 0) == -1) {
    perror("can't shutdown.");
    return -1;
  }

  return 0;
}