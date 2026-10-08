#ifndef LA_COMMON_ASSERT_H
#define LA_COMMON_ASSERT_H

/* Assertion support that terminates through the same simulator trap path. */
void la_assert_fail(const char *expr, const char *file, int line, const char *func) __attribute__((noreturn));

#ifndef NDEBUG
#define LA_ASSERT(expr) ((expr) ? (void)0 : la_assert_fail(#expr, __FILE__, __LINE__, __func__))
#else
#define LA_ASSERT(expr) ((void)0)
#endif

#endif
