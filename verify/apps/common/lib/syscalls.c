#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

#include "la_config.h"
#include "la_heap.h"
#include "la_io.h"
#include "la_runtime.h"
#include "la_timer.h"

/*
 * Minimal syscall surface for freestanding builds that still pull in compiler
 * or newlib-style helper references. Unsupported operations fail harmlessly.
 */
/* newlib-style heap extension hook. */
void *_sbrk(ptrdiff_t increment)
{
    return la_sbrk(increment);
}

/* POSIX-style heap extension hook. */
void *sbrk(ptrdiff_t increment)
{
    return la_sbrk(increment);
}

/* Write stdout/stderr bytes to the simulator console. */
int _write(int fd, const void *buf, size_t count)
{
    /* stdout/stderr are mapped to the simulator console. */
    if (fd == STDOUT_FILENO || fd == STDERR_FILENO) {
        return (int)la_write(buf, count);
    }

    return -1;
}

/* Input is not modeled; report end-of-file to callers. */
int _read(int fd, void *buf, size_t count)
{
    (void)fd;
    (void)buf;
    (void)count;
    return 0;
}

/* File descriptors are not backed by closeable host resources. */
int _close(int fd)
{
    (void)fd;
    return -1;
}

/* Report a character-device-like file status for stdio compatibility. */
int _fstat(int fd, struct stat *st)
{
    (void)fd;
    /* Treat every valid output fd as a character device. */
    st->st_mode = S_IFCHR;
    return 0;
}

/* Treat stdout and stderr as terminal devices. */
int _isatty(int fd)
{
    return (fd == STDOUT_FILENO || fd == STDERR_FILENO);
}

/* Seeking is meaningless for console-only I/O. */
off_t _lseek(int fd, off_t offset, int whence)
{
    (void)fd;
    (void)offset;
    (void)whence;
    return 0;
}

/* Return a stable dummy process id for libc helpers. */
int _getpid(void)
{
    return 1;
}

/* Signals are unsupported in the bare-metal runtime. */
int _kill(int pid, int sig)
{
    (void)pid;
    (void)sig;
    return -1;
}

/* Low-level exit hook used by libc/compiler helper paths. */
void _exit(int code)
{
    la_exit(code);
}

/* Provide a coarse time-of-day value derived from the simulated cycle counter. */
int gettimeofday(struct timeval *tv, void *tz)
{
    uint64_t cycles = la_get_cycles();

    (void)tz;
    if (tv != 0) {
        /* Convert simulated cycles with the configured system frequency. */
        tv->tv_sec = (time_t)(cycles / LA_SYS_FREQ_HZ);
        tv->tv_usec = (suseconds_t)((cycles % LA_SYS_FREQ_HZ) / (LA_SYS_FREQ_HZ / 1000000UL));
    }

    return 0;
}
