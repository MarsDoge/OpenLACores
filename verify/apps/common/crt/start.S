
.text

#include "la_config.h"

.globl _start

#if __loongarch_grlen == 64
#define LI     li.d
#define ADDI   addi.d
#define SLLI   slli.d
#define SUB    sub.d
#define STORE  st.d
#define DMW1_INIT 0x8000000000000009
#else
#define LI     li.w
#define ADDI   addi.w
#define SLLI   slli.w
#define SUB    sub.w
#define STORE  st.w
#define DMW1_INIT 0x80000009
#endif

#define LA_HART_STACK_SHIFT 13
#define LA_HART_STACK_SIZE  8192
#define LA_HART_COUNT       4

_start:
    LI $r1, 0
    LI $r2, 0
    la $r3, _stack_end
    LI $r4, 0
    LI $r5, 0
    LI $r6, 0
    LI $r7, 0
    LI $r8, 0
    LI $r9, 0
    LI $r10, 0
    LI $r11, 0
    LI $r12, 0
    LI $r13, 0
    LI $r14, 0
    LI $r15, 0
    LI $r16, 0
    LI $r17, 0
    LI $r18, 0
    LI $r19, 0
    LI $r20, 0
    LI $r21, 0
    LI $r22, 0
    LI $r23, 0
    LI $r24, 0
    LI $r25, 0
    LI $r26, 0
    LI $r27, 0
    LI $r28, 0
    LI $r29, 0
    LI $r30, 0
    LI $r31, 0

    LI $r11, 0x11
    csrwr $r11, 0x180 

    LI $r11, DMW1_INIT
    csrwr $r11, 0x181

    LI  $r12, 0x10
    csrwr $r12, 0x0  # Cache ON

    li.w    $r11, 0x00100000
    li.w    $r12, 0x00100010
    csrxchg $r11, $r12, 0xaf # Enable BTB and the cycle counter

    la $r13, __enter_main
    csrwr $r13, 0x6
    ertn

__enter_main:
    # The reset prefix intentionally remains identical for single-core
    # DiffTest.  Select a private 8 KiB stack only after entering direct mode.
    csrrd $r4, 0x20
    la $r3, _stack_end
    SLLI $r12, $r4, LA_HART_STACK_SHIFT
    SUB $r3, $r3, $r12

    # Hart zero owns C runtime initialization.  Secondary harts wait inside
    # la_runtime_init until the BSS and constructor writes are published.
    la $r12, la_runtime_init
    jirl $r1, $r12, 0

    LI $r4, 0
    LI $r5, 0
    la $r12, main
    jirl $r1, $r12, 0

    la $r12, exit
    jirl $r1, $r12, 0
    b sys_exit

sys_exit:

1:
    addi.w $r0, $r0, LA_EXIT_INSN_GOOD
    b 1b 

   
.section .expt.text
.globl  expt_vector
.type   expt_vector, @function
expt_vector:    
    bl enter_expt

    # modify era, next inst
    csrrd $r13, 0x6
    ADDI $r13, $r13, 4
    csrwr $r13, 0x6
    ertn

######################
###   data area
######################
    .globl  exit_pc
    .section        .dymmy_exit,"aw",@nobits
    .align  3
    .type   exit_pc, @object
    .size   exit_pc, 8
exit_pc:
    .space  8

    .globl  stack
    .section  .stack,"aw",@nobits
    .align  3
    .type   stack, @object
    .size   stack, LA_HART_STACK_SIZE * LA_HART_COUNT
stack:
    .space  LA_HART_STACK_SIZE * LA_HART_COUNT
