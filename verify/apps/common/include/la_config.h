#ifndef LA_COMMON_CONFIG_H
#define LA_COMMON_CONFIG_H

#ifndef __ASSEMBLER__
#include <stdint.h>
#endif

/* Central board/runtime constants for the LoongArch verification apps. */
#define LA_SYS_FREQ_HZ 100000000UL
#define LA_APB_FREQ_HZ 100000000UL
#define LA_BAUDRATE    19200UL

#define LA_UART0_BASE  0x1fe00000UL
#define LA_TIMER0_BASE 0x1fe10000UL

/*
 * The simulator exposes a byte-wide console sink at different virtual
 * addresses for LA32 and LA64. printf/fputc ultimately writes here.
 */
#if __loongarch_grlen == 64
#define LA_CONSOLE_MMIO_ADDR 0x800000001FE00000ULL
#else
#define LA_CONSOLE_MMIO_ADDR 0x9FE00000UL
#endif

/* CoreMark workload length. */
#define LA_COREMARK_ITERATIONS 3000U

/* Difftest treats these self-loop instructions as good/bad trap markers. */
#define LA_EXIT_INSN_GOOD 52
#define LA_EXIT_INSN_BAD  53

#endif
