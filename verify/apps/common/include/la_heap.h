#ifndef LA_COMMON_HEAP_H
#define LA_COMMON_HEAP_H

#include <stddef.h>

/* Simple heap API backed by linker-provided _heap_start/_heap_end symbols. */
void *la_sbrk(ptrdiff_t increment);
void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
char *strdup(const char *s);

#endif
