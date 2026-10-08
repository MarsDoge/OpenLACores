#ifndef LA_COMMON_STRING_H
#define LA_COMMON_STRING_H

#include <stddef.h>

/* Small libc-compatible string subset for freestanding verification apps. */
void *memcpy(void *dest, const void *src, size_t len);
void *memmove(void *dest, const void *src, size_t len);
void *memset(void *dest, int byte, size_t len);
int memcmp(const void *s1, const void *s2, size_t len);
size_t strlen(const char *s);
size_t strnlen(const char *s, size_t maxlen);
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t len);
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t len);
char *strchr(const char *s, int ch);
char *strrchr(const char *s, int ch);
char *strstr(const char *haystack, const char *needle);
long atol(const char *str);

#endif
