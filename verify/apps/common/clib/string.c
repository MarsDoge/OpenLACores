#include <stddef.h>
#include <stdint.h>

#include "string.h"

/* Freestanding string/memory routines used when no libc is linked. */
#if defined(__GNUC__) && !defined(__llvm__)
#pragma GCC optimize("no-tree-loop-distribute-patterns")
#endif

/* Copy len bytes from src to dest; ranges must not overlap. */
void *memcpy(void *dest, const void *src, size_t len)
{
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    /* Copy whole words first when both ends are naturally aligned. */
    if ((((uintptr_t)d | (uintptr_t)s) & (sizeof(uintptr_t) - 1U)) == 0) {
        while (len >= sizeof(uintptr_t)) {
            *(uintptr_t *)d = *(const uintptr_t *)s;
            d += sizeof(uintptr_t);
            s += sizeof(uintptr_t);
            len -= sizeof(uintptr_t);
        }
    }

    while (len-- != 0U) {
        *d++ = *s++;
    }

    return dest;
}

/* Copy len bytes while safely handling overlapping ranges. */
void *memmove(void *dest, const void *src, size_t len)
{
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (d == s || len == 0U) {
        return dest;
    }

    if (d < s) {
        return memcpy(dest, src, len);
    }

    /* Backward copy handles overlapping ranges where dest starts inside src. */
    d += len;
    s += len;
    while (len-- != 0U) {
        *--d = *--s;
    }

    return dest;
}

/* Fill len bytes at dest with the low byte of byte. */
void *memset(void *dest, int byte, size_t len)
{
    unsigned char *d = (unsigned char *)dest;

    while (len-- != 0U) {
        *d++ = (unsigned char)byte;
    }

    return dest;
}

/* Compare two byte ranges lexicographically. */
int memcmp(const void *s1, const void *s2, size_t len)
{
    const unsigned char *p1 = (const unsigned char *)s1;
    const unsigned char *p2 = (const unsigned char *)s2;

    while (len-- != 0U) {
        if (*p1 != *p2) {
            return (int)*p1 - (int)*p2;
        }
        p1++;
        p2++;
    }

    return 0;
}

/* Return the length of a NUL-terminated string. */
size_t strlen(const char *s)
{
    const char *p = s;

    while (*p != '\0') {
        p++;
    }

    return (size_t)(p - s);
}

/* Return the string length capped at maxlen bytes. */
size_t strnlen(const char *s, size_t maxlen)
{
    const char *p = s;

    while (maxlen-- != 0U && *p != '\0') {
        p++;
    }

    return (size_t)(p - s);
}

/* Compare two NUL-terminated strings lexicographically. */
int strcmp(const char *s1, const char *s2)
{
    unsigned char c1;
    unsigned char c2;

    do {
        c1 = (unsigned char)*s1++;
        c2 = (unsigned char)*s2++;
    } while (c1 != 0U && c1 == c2);

    return (int)c1 - (int)c2;
}

/* Compare at most len bytes of two strings. */
int strncmp(const char *s1, const char *s2, size_t len)
{
    unsigned char c1;
    unsigned char c2;

    while (len-- != 0U) {
        c1 = (unsigned char)*s1++;
        c2 = (unsigned char)*s2++;
        if (c1 != c2 || c1 == 0U) {
            return (int)c1 - (int)c2;
        }
    }

    return 0;
}

/* Copy a NUL-terminated string into dest. */
char *strcpy(char *dest, const char *src)
{
    char *d = dest;

    while ((*d++ = *src++) != '\0') {
    }

    return dest;
}

/* Copy a string into a fixed-width field, padding with NUL bytes. */
char *strncpy(char *dest, const char *src, size_t len)
{
    char *d = dest;

    while (len != 0U && *src != '\0') {
        *d++ = *src++;
        len--;
    }

    while (len-- != 0U) {
        *d++ = '\0';
    }

    return dest;
}

/* Find the first occurrence of ch in s. */
char *strchr(const char *s, int ch)
{
    char c = (char)ch;

    while (*s != '\0') {
        if (*s == c) {
            return (char *)s;
        }
        s++;
    }

    return c == '\0' ? (char *)s : 0;
}

/* Find the last occurrence of ch in s. */
char *strrchr(const char *s, int ch)
{
    const char *last = 0;
    char c = (char)ch;

    do {
        if (*s == c) {
            last = s;
        }
    } while (*s++ != '\0');

    return (char *)last;
}

/* Find the first occurrence of needle in haystack. */
char *strstr(const char *haystack, const char *needle)
{
    size_t needle_len;

    if (*needle == '\0') {
        return (char *)haystack;
    }

    needle_len = strlen(needle);
    while (*haystack != '\0') {
        if (*haystack == *needle && memcmp(haystack, needle, needle_len) == 0) {
            return (char *)haystack;
        }
        haystack++;
    }

    return 0;
}

/* Parse a signed decimal long value from a string. */
long atol(const char *str)
{
    long result = 0;
    int negative = 0;

    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') {
        str++;
    }

    if (*str == '-' || *str == '+') {
        negative = (*str == '-');
        str++;
    }

    while (*str >= '0' && *str <= '9') {
        result = result * 10 + (*str - '0');
        str++;
    }

    return negative ? -result : result;
}
