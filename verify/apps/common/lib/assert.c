#include "la_assert.h"
#include "la_runtime.h"
#include "printf.h"

/* Print assertion context and route failure through la_exit(1). */
void la_assert_fail(const char *expr, const char *file, int line, const char *func)
{
    printf("assertion failed: %s at %s:%d (%s)\n", expr, file, line, func ? func : "?");
    abort();
}

/* glibc-style assert failure hook. */
void __assert_fail(const char *expr, const char *file, unsigned int line, const char *func)
{
    la_assert_fail(expr, file, (int)line, func);
}

/* newlib-style assert failure hook. */
void __assert_func(const char *file, int line, const char *func, const char *expr)
{
    la_assert_fail(expr, file, line, func);
}
