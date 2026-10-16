/* SPDX-License-Identifier: MulanPSL-2.0 */
/* Place at the reset entry or insert before boot code using these registers.
 * Results: r14/r15 are defined CPUCFG values; r13/r16/r17/r18 must be zero.
 * No stack, RAM data area, UART or MMU setup is required.
 */
.section .text
.globl _start
_start:
    cpucfg  $r14, $r0
    ori     $r12, $r0, 1
    cpucfg  $r15, $r12
    ori     $r12, $r0, 0x20
    cpucfg  $r16, $r12
    lu12i.w $r12, 4
    cpucfg  $r13, $r12
    ori     $r12, $r12, 1
    cpucfg  $r17, $r12
    lu12i.w $r12, 0x80000
    cpucfg  $r18, $r12
1:  b       1b
