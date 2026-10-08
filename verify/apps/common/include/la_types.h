#ifndef LA_COMMON_TYPES_H
#define LA_COMMON_TYPES_H

#include <stddef.h>
#include <stdint.h>

/* Volatile register aliases shared by lightweight device drivers. */
typedef volatile uint8_t la_reg8_t;
typedef volatile uint16_t la_reg16_t;
typedef volatile uint32_t la_reg32_t;
typedef volatile uint64_t la_reg64_t;

#ifndef SUCCESS
#define SUCCESS 0
#endif

#ifndef FAILURE
#define FAILURE 1
#endif

#endif
