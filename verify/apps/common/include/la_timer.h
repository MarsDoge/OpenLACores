#ifndef LA_COMMON_TIMER_H
#define LA_COMMON_TIMER_H

#include <stdint.h>

/* Timer facade backed by the architecture time counter. */
uint64_t la_read_time(void);
uint64_t la_get_cycles(void);
int get_vtimer(void);
void sim_end(void);

#endif
