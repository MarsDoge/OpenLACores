# Common LoongArch bare-metal toolchain selection.
#
# Usage:
#   make LA_PROFILE=la32r
#   make LA_PROFILE=la64
#
# The CROSS_COMPILE variable is still honored, so local and CI environments can
# override the selected default prefix without editing app Makefiles.

LA_PROFILE ?= la32r
_la_profile := $(strip $(LA_PROFILE))

ifeq ($(_la_profile),loongarch32r)
  override LA_PROFILE := la32r
else ifeq ($(_la_profile),LA32R)
  override LA_PROFILE := la32r
else ifeq ($(_la_profile),32r)
  override LA_PROFILE := la32r
else ifeq ($(_la_profile),loongarch32s)
  override LA_PROFILE := la32s
else ifeq ($(_la_profile),LA32S)
  override LA_PROFILE := la32s
else ifeq ($(_la_profile),32s)
  override LA_PROFILE := la32s
else ifeq ($(_la_profile),loongarch64)
  override LA_PROFILE := la64
else ifeq ($(_la_profile),LA64)
  override LA_PROFILE := la64
else ifeq ($(_la_profile),64)
  override LA_PROFILE := la64
else ifeq ($(_la_profile),la32r)
else ifeq ($(_la_profile),la32s)
else ifeq ($(_la_profile),la64)
else
  $(error Unknown LA_PROFILE=$(_la_profile), expected la32r/la32s/la64)
endif

LA32R_CROSS_COMPILE ?= loongarch32r-unknown-linux-gnusf-
LA32S_CROSS_COMPILE ?= loongarch32s-unknown-linux-gnusf-
LA64_CROSS_COMPILE  ?= loongarch64-linux-gnu-

ifeq ($(LA_PROFILE),la32r)
  XLEN ?= 32
  CROSS_COMPILE ?= $(LA32R_CROSS_COMPILE)
  LOONGARCH_DV_TARGET ?= loongarch32r
  LOONGARCH_REF_CORE ?= la32r
else ifeq ($(LA_PROFILE),la32s)
  XLEN ?= 32
  CROSS_COMPILE ?= $(LA32S_CROSS_COMPILE)
  LOONGARCH_DV_TARGET ?= loongarch32s
  LOONGARCH_REF_CORE ?= la32s
else ifeq ($(LA_PROFILE),la64)
  XLEN ?= 64
  CROSS_COMPILE ?= $(LA64_CROSS_COMPILE)
  LOONGARCH_DV_TARGET ?= loongarch64
  LOONGARCH_REF_CORE ?= swiftcore
else
  $(error Unknown LA_PROFILE=$(LA_PROFILE), expected la32r/la32s/la64)
endif

ifeq ($(origin CC),default)
  CC := $(CROSS_COMPILE)gcc
endif
ifeq ($(origin LD),default)
  LD := $(CROSS_COMPILE)ld
endif
ifeq ($(origin AR),default)
  AR := $(CROSS_COMPILE)ar
endif
OBJDUMP ?= $(CROSS_COMPILE)objdump
OBJCOPY ?= $(CROSS_COMPILE)objcopy
SIZE    ?= $(CROSS_COMPILE)size
LIBGCC  ?= $(shell $(CC) -print-libgcc-file-name)

ENTRY_ADDR ?= 0x1C000000
LDSTART ?= --defsym=MEM_START=$(ENTRY_ADDR)

COMMON_CFLAGS ?= -static -G0 -pipe -Wa,-mla-global-with-pcrel -fPIC -g -ffreestanding
COMMON_LDFLAGS ?= $(LDSTART) -static -G0
