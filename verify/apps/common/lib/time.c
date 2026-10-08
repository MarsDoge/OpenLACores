#include <stdint.h>
#include <time.h>

#include "config.h"
#include "la_timer.h"

/* Return a monotonically increasing cycle-like value for bare-metal tests. */
uint64_t la_read_time(void)
{
#if __loongarch_grlen == 64
    uint64_t value;
    __asm__ volatile("rdtime.d %0, $zero" : "=r"(value));
    return value;
#else
    uint32_t value;
    __asm__ volatile("rdtimel.w %0, $zero" : "=r"(value));
    return (uint64_t)value;
#endif
}

/* Alias the runtime timer as a cycle counter for app code. */
uint64_t la_get_cycles(void)
{
    return la_read_time();
}

/* Legacy virtual timer API used by CoreMark and older tests. */
int get_vtimer(void)
{
    return (int)la_read_time();
}

/* C library clock() compatibility wrapper. */
clock_t clock(void)
{
    return (clock_t)get_vtimer();
}

/* Placeholder hook for tests that want an explicit simulation end point. */
void sim_end(void)
{
}
