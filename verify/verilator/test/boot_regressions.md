# LA132 boot-visible RTL regressions

Baseline: `6403ab5e3a6c8293a48456bcc8a4de5ff8db1930`.
Run from the repository root with Icarus Verilog 11 or later:

```sh
bash verify/verilator/test/cpucfg_boot.sh
bash verify/verilator/test/invtlb_boot.sh
bash verify/verilator/test/cpucfg_cache.sh
```

Set `IVERILOG` and `VVP` to override executable paths. The boot tests instantiate
`openla132_ip_top`, supply a ROM at reset PC 0x1c000000 and observe register
writeback. They do not force internal state. Corresponding `.S` files document
the encoded ROM instructions; the tests need no cross assembler. Reset data-path
initialization is enabled for deterministic four-state simulation. The MMU
configuration needs more than 1024 cycles for cache initialization.

## Full CPUCFG index

The original 14-bit index path aliases 0x4000 to CPUCFG[0], returning PRID rather
than zero. Preserve all 32 bits and reject indexes outside the supported range.
The boot test checks valid indexes 0 and 1 and undefined indexes 0x20, 0x4000,
0x4001 and 0x80000000. Original RTL fails at 0x4000; patched RTL passes.

## Reserved INVTLB operations

With CONFIG_MMU enabled, the original decoder recognizes every INVTLB op, even
reserved values 7..31. The boot test writes EENTRY, executes legal ops 0 and 6,
then a reserved op. Original RTL reaches the failure marker after op 7. Patched
RTL takes INE, reports Ecode 0xd and saves the reserved instruction PC in ERA.
The script repeats the test for all 25 reserved operations. Legal-op checks
establish that those instructions execute without an exception; they do not
verify their TLB invalidation effects. The exception handler uses a 4-KiB-aligned
entry, as implemented by this core.

## D-cache geometry depends on D-cache presence

CPUCFG[0x12] originally gates the D-cache line-size field with HAS_ICC.
With I-cache absent and D-cache present, 4-way/4-KiB-per-way configuration returns
0x00070003 rather than 0x05070003. With I-cache present and D-cache absent, it
returns 0x05000000 rather than zero. Use HAS_DCC instead.

The module test checks all four independent I/D-cache presence combinations,
including presence flags and complete geometry words. Both asymmetric cases
fail before the fix and all four pass afterward. The stock IP wrapper enables
both caches together, so this bug requires an asymmetric core integration;
it is not a default-wrapper boot failure. Firmware can observe it by reading
CPUCFG index 0x12 on such an integration.

These results are RTL simulation results, not physical LA132 silicon results.
The ISA reference is the LoongArch Reference Manual Volume 1, CPUCFG and INVTLB:
https://loongson.github.io/LoongArch-Documentation/LoongArch-Vol1-EN.html
