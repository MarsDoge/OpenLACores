#include <stdio.h>

#include "la_config.h"
#include "la_io.h"

/* Write one byte to the simulator console MMIO sink. */
int la_putchar(int ch)
{
    *(volatile char *)(uintptr_t)LA_CONSOLE_MMIO_ADDR = (char)ch;
    return ch;
}

/* Write a NUL-terminated string followed by a newline. */
int la_puts(const char *s)
{
    while (*s != '\0') {
        la_putchar(*s++);
    }
    la_putchar('\n');
    return 0;
}

/* Write a raw byte buffer to the simulator console. */
size_t la_write(const void *buf, size_t len)
{
    const char *p = (const char *)buf;

    for (size_t i = 0; i < len; i++) {
        la_putchar(p[i]);
    }

    return len;
}

/* stdio compatibility hook used by the local printf implementation. */
int fputc(int ch, FILE *stream)
{
    /* stdio compatibility for the local printf implementation. */
    (void)stream;
    return la_putchar(ch);
}
