// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

#include "entry.h"
#include "bootargs.h"
#include "loader_config.h"

.equ    LOADER_BOOTARGS_ADDR, 0x00100000
.equ    LA32_DMW_PHYS_MASK, 0x1fffffff

.section .text.init, "ax", @progbits
.align  4
.globl _start
.type  _start, @function

_start:
    li.w    $sp, LOADER_STACK_ADDR

    /* Stage 1: reset was released and the loader fetched from boot memory. */
    li.w    $t0, LOADER_STATUS_ADDR
    li.w    $t1, 1
    st.w    $t1, $t0, 0
    dbar    0

    /* Supply a valid physical command-line buffer to the LA32 kernel. */
    la.local $t4, loader_bootargs
    li.w    $t5, LOADER_BOOTARGS_ADDR
1:
    ld.bu   $t6, $t4, 0
    st.b    $t6, $t5, 0
    addi.w  $t4, $t4, 1
    addi.w  $t5, $t5, 1
    bnez    $t6, 1b
    dbar    0

    bl      boot_uart_init

    /* Stage 2: UART setup and the loader banner both completed. */
    li.w    $t0, LOADER_STATUS_ADDR
    li.w    $t1, 2
    st.w    $t1, $t0, 0
    dbar    0

    /* Clear the LA32 DMW segment bits [31:29] from the load address. */
    li.w    $t1, KERNEL_ENTRY_DMW
    li.w    $t0, LA32_DMW_PHYS_MASK
    and     $t1, $t1, $t0

    /* Stage 3: the next instruction transfers control to Linux. */
    li.w    $t2, LOADER_STATUS_ADDR
    li.w    $t3, 3
    st.w    $t3, $t2, 0
    dbar    0

    move    $a0, $zero
    li.w    $a1, LOADER_BOOTARGS_ADDR
    move    $a2, $zero
    move    $a3, $zero
    jirl    $zero, $t1, 0

    .size   _start, .-_start

.section .rodata, "a", @progbits
.align  2
loader_bootargs:
    .asciz  LOADER_BOOTARGS
