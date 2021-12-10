#ifndef MYTEXT_H
#define MYTEXT_H

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define N 256
#define M 16
#define MAX_WRD 128

#define EXIT_SUCCESS 0
#define WORD_TOOLONG 1
#define STRING_TOOLONG 2
#define INVALID_INPUT 3
#define DATASIZE_FAILURE 4
#define NOT_SOLVABLE 5

typedef char string_t[N + 1];
typedef char text_t[MAX_WRD][M + 1];

long text_input(text_t dst, size_t *num);
long string_separation(string_t src, text_t dst, size_t *words_num);
void text_output(text_t dst, size_t n);

#endif // MYTEXT_H