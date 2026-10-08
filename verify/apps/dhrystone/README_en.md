#	Dhrystone 2.1

This directory contains Reinhold P. Weicker's Dhrystone 2.1 sources adapted
to the OpenLA132S bare-metal runtime.  The benchmark sources retain GNU89
K&R syntax; the shared runtime remains C99.

The default 10,000-run build is intended for correctness and microarchitecture
profiling.  It uses the 100 MHz `rdtime`-backed cycle timer but is shorter than
Dhrystone's two-second score threshold, so its result must not be published as
a standard Dhrystone score.

Compile the strict single-core profile with cross compiler:

```sh
make CROSS_COMPILE=</path/to/cross_compile> -j<thread>
```

The score conversion is:

```text
Dhrystones/s = frequency_hz * runs / measured_loop_ticks
DMIPS         = Dhrystones/s / 1757
DMIPS/MHz     = DMIPS / (frequency_hz / 1e6)
```

Only the loop timer delta printed by the benchmark is valid for this formula;
the emulator's reset-to-trap cycle count includes initialization and output.
