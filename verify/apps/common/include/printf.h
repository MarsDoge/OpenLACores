#ifndef LA_COMMON_PRINTF_H
#define LA_COMMON_PRINTF_H

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>

int printf(const char *format, ...);
int sprintf(char *buffer, const char *format, ...);
int snprintf(char *buffer, size_t count, const char *format, ...);
int vprintf(const char *format, va_list va);
int la_vprintf(const char *format, va_list va);
int vsnprintf(char *buffer, size_t count, const char *format, va_list va);
int vasprintf(char **ret, const char *fmt, va_list ap);
int asprintf(char **buf, const char *fmt, ...);
int puts(const char *s);
int putchar(int c);
int fputc(int ch, FILE *stream);
char *strdup(const char *s);

#endif
