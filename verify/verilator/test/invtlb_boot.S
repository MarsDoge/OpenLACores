/* SPDX-License-Identifier: MulanPSL-2.0 */
/* Link at 0x1c000000. Requires CONFIG_MMU, reset PLV0 and direct addressing.
 * Expected: ERA=0x1c000014, ESTAT.Ecode=0xd; r13 must not become 1.
 * The RTL test also substitutes every reserved op from 7 through 31.
 */
.section .text
.globl _start
_start:
    lu12i.w $r12, 0x1c001
    ori     $r12, $r12, 0
    csrwr   $r12, 0xc
    invtlb  0, $r0, $r0
    invtlb  6, $r0, $r0
    .word   0x06498007
    addi.w  $r13, $r0, 1
1:  b       1b
.org 0x1000
exception:
    csrrd   $r15, 0x6
    csrrd   $r14, 0x5
2:  b       2b
