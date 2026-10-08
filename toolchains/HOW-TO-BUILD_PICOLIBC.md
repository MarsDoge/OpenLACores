# Build Picolibc for LA32S

Run the following commands from the OpenLA132S repository root. Replace the
toolchain directory with the location of your LA32S compiler.

```bash
git clone https://github.com/picolibc/picolibc.git toolchains/picolibc
export PATH=/path/to/loongarch32s-toolchain/bin:$PATH

meson setup toolchains/picolibc/build-la32s toolchains/picolibc \
  --cross-file toolchains/picolibc-la32s.ini \
  --prefix="$PWD/toolchains/picolibc/build-la32s/install" \
  --includedir=include \
  --libdir=lib \
  -Dspecsdir=none \
  -Dmultilib=false \
  -Dtests=false \
  -Dthread-local-storage=false \
  -Datomic-ungetc=false \
  -Dbuildtype=release

ninja -C toolchains/picolibc/build-la32s -j"$(nproc)"
ninja -C toolchains/picolibc/build-la32s install
```
