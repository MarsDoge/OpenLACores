#ifndef LA_COMMON_IO_H
#define LA_COMMON_IO_H

#include <stddef.h>

/* Console output primitives used by printf and syscall write stubs. */
int la_putchar(int ch);
int la_puts(const char *s);
size_t la_write(const void *buf, size_t len);

#endif
