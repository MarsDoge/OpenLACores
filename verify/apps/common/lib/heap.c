#include <stdint.h>

#include "la_heap.h"
#include "string.h"

/* Heap bounds are provided by linker.script after the static stack region. */
extern char _heap_start[];
extern char _heap_end[];

typedef struct {
    size_t size;
} la_alloc_header_t;

static uintptr_t heap_cursor;

/* Round an address or size up to the requested power-of-two alignment. */
static uintptr_t la_align_up(uintptr_t value, uintptr_t align)
{
    return (value + align - 1U) & ~(align - 1U);
}

/* Move the heap cursor by increment bytes and return the previous break. */
void *la_sbrk(ptrdiff_t increment)
{
    uintptr_t current;
    uintptr_t next;
    uintptr_t heap_limit = (uintptr_t)_heap_end;

    if (heap_cursor == 0) {
        /* Lazily initialize so startup code does not need a heap phase. */
        heap_cursor = la_align_up((uintptr_t)_heap_start, sizeof(uintptr_t));
    }

    current = heap_cursor;
    if (increment < 0) {
        next = current - (uintptr_t)(-increment);
        if (next < (uintptr_t)_heap_start) {
            return (void *)-1;
        }
    } else {
        next = current + (uintptr_t)increment;
        if (next > heap_limit || next < current) {
            return (void *)-1;
        }
    }

    heap_cursor = la_align_up(next, sizeof(uintptr_t));
    return (void *)current;
}

/* Allocate a heap block from the bump allocator. */
void *malloc(size_t size)
{
    la_alloc_header_t *hdr;
    size_t payload;
    size_t total;

    if (size == 0) {
        size = 1;
    }

    payload = la_align_up(size, sizeof(uintptr_t));
    total = payload + sizeof(*hdr);
    hdr = (la_alloc_header_t *)la_sbrk((ptrdiff_t)total);
    if (hdr == (void *)-1) {
        return 0;
    }

    hdr->size = size;
    return (void *)(hdr + 1);
}

/* Free is intentionally a no-op for the bump allocator. */
void free(void *ptr)
{
    /* Bump allocation has no reclaim path; apps are short-lived tests. */
    (void)ptr;
}

/* Allocate and zero count * size bytes, with overflow protection. */
void *calloc(size_t count, size_t size)
{
    size_t total = count * size;
    void *ptr;

    if (size != 0 && total / size != count) {
        return 0;
    }

    ptr = malloc(total);
    if (ptr != 0) {
        memset(ptr, 0, total);
    }

    return ptr;
}

/* Allocate a new block, copy the old payload, and leave the old block live. */
void *realloc(void *ptr, size_t size)
{
    la_alloc_header_t *old_hdr;
    void *new_ptr;
    size_t copy_size;

    if (ptr == 0) {
        return malloc(size);
    }

    if (size == 0) {
        free(ptr);
        return 0;
    }

    old_hdr = ((la_alloc_header_t *)ptr) - 1;
    new_ptr = malloc(size);
    if (new_ptr == 0) {
        return 0;
    }

    copy_size = old_hdr->size < size ? old_hdr->size : size;
    memcpy(new_ptr, ptr, copy_size);
    return new_ptr;
}

/* Duplicate a NUL-terminated string into heap memory. */
char *strdup(const char *s)
{
    size_t len = strlen(s) + 1U;
    char *copy = (char *)malloc(len);

    if (copy == 0) {
        return 0;
    }

    memcpy(copy, s, len);
    return copy;
}
