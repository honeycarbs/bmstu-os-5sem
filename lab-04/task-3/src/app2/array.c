#include "array.h"

int input(array_t a, size_t n) {
    size_t i;
    printf("Input %zu elements of the array:\n", n);
    for (i = 0; i < n; i++)
        if (scanf("%ld", a + i) != 1) return EXIT_FAILURE;
    return EXIT_SUCCESS;
}

void output(array_t a, size_t n) {
    for (size_t i = 0; i < n; i++) printf("%ld ", a[i]);
    puts("");
}