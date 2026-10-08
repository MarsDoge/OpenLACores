#ifndef LA_COMMON_LEGACY_TIMER_H
#define LA_COMMON_LEGACY_TIMER_H

#include "la_config.h"
#include "la_timer.h"

/* Legacy timer facade; real timing is provided by la_timer.h/lib/time.c. */
#define TIMER_PERIOD 0xffffffffU
#define SMART_TIMER_BASE LA_TIMER0_BASE

/* Compatibility stub for old code that starts a platform timer. */
static inline int start_timer(void)
{
    /* No programmable timer is required for current simulator workloads. */
    return 0;
}

/* Compatibility stub for old code that starts a timer with a reload value. */
static inline int start_set_timer(int value)
{
    (void)value;
    return 0;
}

/* Return the current virtual timer value through the common timer API. */
static inline int get_timer(void)
{
    /* Preserve old callers while routing reads through the common timer API. */
    return get_vtimer();
}

/* Return the current virtual timer value when old code stops the timer. */
static inline int stop_timer(void)
{
    return get_vtimer();
}

#endif
