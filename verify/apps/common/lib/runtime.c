#include <stddef.h>

#include "la_config.h"
#include "la_runtime.h"
#include "string.h"

#define LA_STRINGIFY_INNER(value) #value
#define LA_STRINGIFY(value) LA_STRINGIFY_INNER(value)

/* These symbols are defined by verify/common/linker.script. */
extern char _bss_start[];
extern char _bss_end[];

extern void (*__preinit_array_start[])(void);
extern void (*__preinit_array_end[])(void);
extern void (*__init_array_start[])(void);
extern void (*__init_array_end[])(void);
extern void (*__fini_array_start[])(void);
extern void (*__fini_array_end[])(void);

/*
 * Only hart zero initializes shared C state.  The magic value makes the
 * release condition explicit in traces and avoids treating any nonzero data
 * as a completed initialization.
 */
// MAGIC: 'L', 'A', '6', '4'
#define LA_RUNTIME_READY_MAGIC 0x4c413634U

static volatile unsigned int la_runtime_ready;

/* Drain this hart's memory transactions and prevent compiler reordering. */
static void la_memory_barrier(void)
{
    __asm__ volatile("dbar 0" ::: "memory");
}

/* Return the hardware hart identifier exposed by read-only CSR.CPUID. */
unsigned long la_hart_id(void)
{
    unsigned long hart_id;

    __asm__ volatile("csrrd %0, 0x20" : "=r"(hart_id));
    return hart_id;
}

/* Call a linker-defined array of constructor/destructor function pointers. */
static void la_call_array(void (**begin)(void), void (**end)(void))
{
    /* Constructor arrays are optional, but supporting them costs little. */
    while (begin < end) {
        (*begin++)();
    }
}

/* Initialize shared C state once, then release every secondary hart. */
void la_runtime_init(unsigned long hart_id)
{
    if (hart_id == 0UL) {
        /* Build images may contain a loaded .bss; clear it for C startup. */
        memset(_bss_start, 0, (size_t)(_bss_end - _bss_start));
        la_call_array(__preinit_array_start, __preinit_array_end);
        la_call_array(__init_array_start, __init_array_end);

        /* Publish the initialized state only after all earlier stores drain. */
        la_memory_barrier();
        la_runtime_ready = LA_RUNTIME_READY_MAGIC;
        la_memory_barrier();
        return;
    }

    while (la_runtime_ready != LA_RUNTIME_READY_MAGIC) {
        __asm__ volatile("" ::: "memory");
    }
    la_memory_barrier();
}

/* Run finalizers in reverse order when the bare-metal program exits. */
static void la_runtime_fini(void)
{
    void (**p)(void) = __fini_array_end;

    while (p > __fini_array_start) {
        (*--p)();
    }
}

/* Terminate simulation with a difftest-visible good or bad trap marker. */
void la_exit(int code)
{
    if (la_hart_id() == 0UL) {
        la_runtime_fini();
    }

    if (code == 0) {
        /* Keep the configured good-trap instruction visible to difftest. */
        for (;;) {
            __asm__ volatile("addi.w $r0, $r0, " LA_STRINGIFY(LA_EXIT_INSN_GOOD));
        }
    }

    /* Non-zero exits intentionally use a different marker. */
    for (;;) {
        __asm__ volatile("addi.w $r0, $r0, " LA_STRINGIFY(LA_EXIT_INSN_BAD));
    }
}

/* Standard C exit() compatibility wrapper. */
void exit(int code)
{
    la_exit(code);
}

/* Standard C abort() compatibility wrapper. */
void abort(void)
{
    la_exit(1);
}
