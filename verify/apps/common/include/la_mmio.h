#ifndef LA_COMMON_MMIO_H
#define LA_COMMON_MMIO_H

#include <stdint.h>

/* Typed MMIO helpers keep device code away from ad-hoc volatile casts. */
/* Read one byte from an MMIO address. */
static inline uint8_t la_mmio_read8(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}

/* Read one halfword from an MMIO address. */
static inline uint16_t la_mmio_read16(uintptr_t addr)
{
    return *(volatile uint16_t *)addr;
}

/* Read one word from an MMIO address. */
static inline uint32_t la_mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

/* Read one doubleword from an MMIO address. */
static inline uint64_t la_mmio_read64(uintptr_t addr)
{
    return *(volatile uint64_t *)addr;
}

/* Write one byte to an MMIO address. */
static inline void la_mmio_write8(uintptr_t addr, uint8_t value)
{
    *(volatile uint8_t *)addr = value;
}

/* Write one halfword to an MMIO address. */
static inline void la_mmio_write16(uintptr_t addr, uint16_t value)
{
    *(volatile uint16_t *)addr = value;
}

/* Write one word to an MMIO address. */
static inline void la_mmio_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

/* Write one doubleword to an MMIO address. */
static inline void la_mmio_write64(uintptr_t addr, uint64_t value)
{
    *(volatile uint64_t *)addr = value;
}

#endif
