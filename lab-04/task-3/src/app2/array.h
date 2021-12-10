#ifndef ARRAY_H
#define ARRAY_H

#include <stdio.h>
#include <stdlib.h>

#define N 20

typedef long array_t[N];

int input(array_t a, size_t n);
void output(array_t a, size_t n);

#endif // ARRAY_H