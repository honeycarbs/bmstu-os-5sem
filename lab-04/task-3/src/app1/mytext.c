#define __USE_MINGW_ANSI_STDIO 1
#include <ctype.h>
#include <stdio.h>
#include "mytext.h"


long text_input(text_t dst, size_t *num)
{
    string_t separators = ". ,;:-!?";
    size_t j = 0;
    size_t strlen = 0;
    long flag = 0;
    char ch = 0;
    while ((ch = getchar()) != '\n' && ch != EOF)
    {
        strlen++;
        if (strlen > 256)
            return STRING_TOOLONG;
        if (strchr(separators, ch) == NULL)
        {
            if (j > 16)
                return WORD_TOOLONG;
            flag = 1;
            dst[*num][j] = ch;
            j++;
        }
        if (strchr(separators, ch) != NULL)
            if (flag == 1)
            {
                flag = 0;
                dst[*num][j] = '\0';
                j = 0;
                *num = *num + 1;
            }
    }
    if (ch == '\n' || ch == EOF)
        if (flag == 1)
        {
            if (j > 16)
                return WORD_TOOLONG;
            dst[*num][j] = '\0';
            *num = *num + 1;
        }
    if (*num == 0)
        return INVALID_INPUT;
    else
        return EXIT_SUCCESS;
}

void text_output(text_t text, size_t n)
{
    printf("Result: ");
    size_t j;
    for (size_t i = 0; i < n; i++)
    {
        j = 0;
        while (text[i][j] != '\0')
        {
            printf("%c", text[i][j]);
            j++;
        }
        printf(" ");
    }
}