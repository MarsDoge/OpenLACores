#ifndef LA_COMMON_RUNTIME_H
#define LA_COMMON_RUNTIME_H

/* Minimal C runtime lifecycle called by crt/start.S. */
void la_runtime_init(unsigned long hart_id);
unsigned long la_hart_id(void);
void la_exit(int code) __attribute__((noreturn));
void exit(int code) __attribute__((noreturn));
void abort(void) __attribute__((noreturn));

#endif
