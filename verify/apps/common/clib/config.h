#ifndef LA_COMMON_LEGACY_CONFIG_H
#define LA_COMMON_LEGACY_CONFIG_H

#include "la_config.h"

/* Compatibility macros for existing apps that include config.h directly. */
#ifndef U32
#define U32 unsigned int
#define U8 unsigned char
#endif

#define BAUDRATE LA_BAUDRATE
#define SYS_FREQ LA_SYS_FREQ_HZ
#define APB_FREQ LA_APB_FREQ_HZ

#ifndef CLOCKS_PER_SEC
#define CLOCKS_PER_SEC APB_FREQ
#endif

#define CONFIG_SYS_SIM 1
#define CORE_DEBUG 0
#define COREMARK_ITERATIONS LA_COREMARK_ITERATIONS

#endif
