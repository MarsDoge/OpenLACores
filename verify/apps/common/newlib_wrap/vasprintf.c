#include <errno.h>
#include <stdarg.h>
#include <stddef.h>

#include "la_heap.h"
#include "printf.h"
#include "string.h"

#define VASPRINTF_CHUNK_SIZE 256U

/* Format into a heap-allocated string using a retrying buffer growth loop. */
int vasprintf(char **ret, const char *fmt, va_list ap)
{
    size_t chunks = ((strlen(fmt) + 1U) / VASPRINTF_CHUNK_SIZE) + 1U;
    size_t buflen = chunks * VASPRINTF_CHUNK_SIZE;
    char *buf;
    int len;

    *ret = 0;
    for (;;) {
        va_list copy;

        buf = (char *)malloc(buflen);
        if (buf == 0) {
            return -ENOMEM;
        }

        /* va_list may be single-pass, so copy it on each retry. */
        va_copy(copy, ap);
        len = vsnprintf(buf, buflen, fmt, copy);
        va_end(copy);

        if (len >= 0 && (size_t)len < buflen) {
            break;
        }

        free(buf);
        chunks++;
        /* Prefer the exact size when vsnprintf reports it. */
        buflen = chunks * VASPRINTF_CHUNK_SIZE;
        if (len >= 0 && buflen <= (size_t)len) {
            buflen = (size_t)len + 1U;
        }
    }

    *ret = buf;
    return len;
}

/* Variadic wrapper around vasprintf(). */
int asprintf(char **buf, const char *fmt, ...)
{
    va_list args;
    int ret;

    va_start(args, fmt);
    ret = vasprintf(buf, fmt, args);
    va_end(args);
    return ret;
}
