# OpenLACores Block Design FPGA flow entry point.

IMPL_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPT_DIR := $(IMPL_DIR)/scripts

# A command-line VIVADO=... assignment takes precedence over this workstation
# default, including when a stale VIVADO value exists in the environment.
VIVADO := vivado
PYTHON ?= python3


BOARD ?= lsbd
SUPPORTED_BOARDS := vu13p lsbd
ifeq ($(filter $(BOARD),$(SUPPORTED_BOARDS)),)
$(error Unsupported BOARD='$(BOARD)'; choose one of: $(SUPPORTED_BOARDS))
endif

CONFIG_MMU ?= 1
CONFIG_MMU_RESOLVED := $(strip $(CONFIG_MMU))
CONFIG_MMU_SUPPORTED := 0 1
ifneq ($(words $(CONFIG_MMU_RESOLVED)),1)
$(error CONFIG_MMU must be exactly one integer from: $(CONFIG_MMU_SUPPORTED))
endif
ifeq ($(filter $(CONFIG_MMU_RESOLVED),$(CONFIG_MMU_SUPPORTED)),)
$(error CONFIG_MMU must be one of: $(CONFIG_MMU_SUPPORTED); got '$(CONFIG_MMU)')
endif

BOARD_CONFIG := $(IMPL_DIR)/boards/$(BOARD).mk
include $(BOARD_CONFIG)


# Pass Defines to Verilog
MMU_SELECTION_DEFINES := CONFIG_MMU CONFIG_MMU=%
MMU_VERILOG_DEFINES := $(if $(filter 1,$(CONFIG_MMU_RESOLVED)),CONFIG_MMU,)
EFFECTIVE_VERILOG_DEFINES := $(strip \
	$(filter-out $(NETWORK_SELECTION_DEFINES) $(MMU_SELECTION_DEFINES),$(VERILOG_DEFINES)) \
	$(MMU_VERILOG_DEFINES))


# JOBS and THREADS are retained as compatibility aliases.  New invocations
# should use the explicit VIVADO_JOBS and VIVADO_THREADS names.
ifdef JOBS
VIVADO_JOBS ?= $(JOBS)
else
VIVADO_JOBS ?= 8
endif
ifdef THREADS
VIVADO_THREADS ?= $(THREADS)
else
VIVADO_THREADS ?= 16
endif

# Resolve user-supplied relative paths from impl/, independent of whether this
# Makefile is entered with "make -C impl" or "make -f impl/Makefile".
resolve_impl_path = $(abspath $(if $(filter /%,$(strip $(1))),$(strip $(1)),$(IMPL_DIR)/$(strip $(1))))

WORK_ROOT_ABS := $(call resolve_impl_path,$(WORK_ROOT))
PROJECT_DIR_ABS := $(call resolve_impl_path,$(PROJECT_DIR))
CONSTRAINT_FILE_ABS := $(call resolve_impl_path,$(CONSTRAINT_FILE))
TOP_FILE_ABS := $(call resolve_impl_path,$(TOP_FILE))
BD_TCL_ABS := $(call resolve_impl_path,$(BD_TCL))
PROJECT_FILE := $(PROJECT_DIR_ABS)/$(PROJECT_NAME).xpr

VIVADO_ENV = env \
	FPGA_BOARD='$(BOARD)' \
	VIVADO_JOBS='$(VIVADO_JOBS)' \
	VIVADO_THREADS='$(VIVADO_THREADS)' \
	FPGA_WORK_ROOT='$(WORK_ROOT_ABS)' \
	FPGA_PROJECT_NAME='$(PROJECT_NAME)' \
	FPGA_PROJECT_DIR='$(PROJECT_DIR_ABS)' \
	FPGA_FILELIST='$(FPGA_FILELIST)' \
	FPGA_PART='$(FPGA_PART)' \
	FPGA_CPU_FREQ_HZ='$(CPU_FREQ_HZ)' \
	FPGA_CONSTRAINT_FILE='$(CONSTRAINT_FILE_ABS)' \
	FPGA_TOP_FILE='$(TOP_FILE_ABS)' \
	FPGA_TOP_MODULE='$(TOP_MODULE)' \
	FPGA_BD_NAME='$(BD_NAME)' \
	FPGA_BD_TCL='$(BD_TCL_ABS)' \
	FPGA_VERILOG_DEFINES='$(EFFECTIVE_VERILOG_DEFINES)' \
	FPGA_SYNTH_STRATEGY='$(FPGA_SYNTH_STRATEGY)' \
	FPGA_HW_TARGET_PATTERN='$(FPGA_HW_TARGET_PATTERN)' \
	FPGA_HW_TARGET_INDEX='$(FPGA_HW_TARGET_INDEX)' \
	FPGA_HW_FREQUENCY_HZ='$(FPGA_HW_FREQUENCY_HZ)' \
	FPGA_HW_DEVICE_PATTERN='$(FPGA_HW_DEVICE_PATTERN)' \
	FPGA_HW_AXI_NAME='$(FPGA_HW_AXI_NAME)' \
	FPGA_JTAG_AXI_ADDR_WIDTH='$(JTAG_AXI_ADDR_WIDTH)' \
	FPGA_JTAG_AXI_DATA_WIDTH='$(JTAG_AXI_DATA_WIDTH)' \
	FPGA_JTAG_AXI_SANITY_ADDRESS='$(JTAG_AXI_SANITY_ADDRESS)' \
	FPGA_UPLOAD_TRANSACTION_BYTES='$(UPLOAD_TRANSACTION_BYTES)'
VIVADO_BATCH = $(VIVADO_ENV) "$(VIVADO)" -mode batch -nojournal -nolog

.DEFAULT_GOAL := all

.PHONY: all help config ips bd project reproject rebuild syn synth check impl bitstream \
	bitstream-la132-ila _bitstream-la132-ila \
	status timing timing-syn timing-impl reports gen_ddr_data upload upload-la132-ila \
	cpu-reset cpu-hold cpu-release \
	capture-lsbd-status-ila \
	capture-la132-ila _capture-la132-ila diagnose-la132-boot \
	jtag-read jtag-write clean

all: project

help:
	@printf '%s\n' \
		'OpenLACores unified FPGA flow (BOARD=$(BOARD); default BOARD=lsbd):' \
		'' \
		'Targets:' \
		'  make                       Default target; same as project' \
		'  make  all                  Same as project' \
		'  make  help                 Show this help' \
		'  make  config               Show the resolved build configuration' \
		'  make  BOARD=vu13p config   Use the VU13P board for this invocation' \
		'  make  BOARD=lsbd  config   Use the LSBD board for this invocation' \
		'  make  project              Create the Vivado project and BD when absent' \
		'  make  ips                  Alias for project' \
		'  make  bd                   Alias for project' \
		'  make  reproject            Force recreation of the Vivado project and BD' \
		'  make  rebuild              Reproject and build a fresh bitstream' \
		'  make  syn                  Run synthesis and write synthesis reports' \
		'  make  synth                Alias for syn' \
		'  make  check                Alias for syn' \
		'  make  impl                 Run implementation through route_design' \
		'  make  bitstream            Run through write_bitstream' \
		'  make  status               Show synth_1 and impl_1 run status' \
		'  make  timing-syn           Report an existing synthesis run' \
		'  make  timing-impl          Report an existing routed run' \
		'  make  timing               Alias for timing-impl' \
		'  make  reports              Alias for timing-impl' \
		'  make  gen_ddr_data         Build loader/kernel upload data without programming' \
		'  make  upload               Upload Linux and verify boundary transactions' \
		'  make  bitstream-la132-ila  Build CPU/MMU/AXI/DCache boot ILAs' \
		'  make  upload-la132-ila     Program boot ILAs, upload Linux, and hold CPU reset' \
		'  make  capture-la132-ila    Arm all boot ILAs and release the held CPU' \
		'  make  diagnose-la132-boot  Build, upload, and capture in one flow' \
		'  make  BOARD=lsbd capture-lsbd-status-ila  Capture LSBD clock/reset/AXI status' \
		'  make  cpu-reset            Pulse VIO CPU reset without changing DDR' \
		'  make  cpu-hold             Assert VIO CPU reset and leave it asserted' \
		'  make  cpu-release          Release an asserted VIO CPU reset' \
		'  make  jtag-read JTAG_ADDR=0x1c100000  Read live DDR through JTAG AXI' \
		'  make  jtag-write JTAG_ADDR=... JTAG_DATA=...  Write live DDR through JTAG AXI' \
		'  make  clean                Remove the selected board WORK_ROOT' \
		'' \
		'Configuration:' \
		'  Build:    BOARD CONFIG_MMU PROJECT_NAME PROJECT_DIR WORK_ROOT FPGA_PART' \
		'            CPU_FREQ_HZ FPGA_FILELIST CONSTRAINT_FILE TOP_FILE TOP_MODULE' \
		'            BD_NAME BD_TCL VERILOG_DEFINES FPGA_SYNTH_STRATEGY' \
		'  Hardware: FPGA_HW_TARGET_PATTERN FPGA_HW_TARGET_INDEX FPGA_HW_FREQUENCY_HZ' \
		'            FPGA_HW_DEVICE_PATTERN FPGA_HW_AXI_NAME JTAG_AXI_ADDR_WIDTH' \
		'            JTAG_AXI_DATA_WIDTH JTAG_AXI_SANITY_ADDRESS' \
		'  Upload:   KERNEL_DIR BIOS_OFFSET KERNEL_OFFSET LOADER_STATUS_OFFSET' \
		'            LOADER_MAX_BYTES LOADER_STACK_ADDR LOADER_BOOTARGS' \
		'            UPLOAD_VERIFY UPLOAD_STATUS_ADDRESS UPLOAD_CPU_ACTION' \
		'            UPLOAD_TRANSACTION_BYTES JTAG_ADDR JTAG_LEN JTAG_DATA' \
		'  Tools:    VIVADO PYTHON VIVADO_JOBS VIVADO_THREADS (JOBS/THREADS aliases)'

config:
	@printf '%-20s %s\n' \
		'BOARD' '$(BOARD)' \
		'CONFIG_MMU' '$(CONFIG_MMU_RESOLVED)' \
		'BOARD_CONFIG' '$(BOARD_CONFIG)' \
		'PROJECT_NAME' '$(PROJECT_NAME)' \
		'PROJECT_DIR' '$(PROJECT_DIR_ABS)' \
		'PROJECT_FILE' '$(PROJECT_FILE)' \
		'WORK_ROOT' '$(WORK_ROOT_ABS)' \
		'FPGA_PART' '$(FPGA_PART)' \
		'CPU_FREQ_HZ' '$(CPU_FREQ_HZ)' \
		'CONSTRAINT_FILE' '$(CONSTRAINT_FILE_ABS)' \
		'TOP_FILE' '$(TOP_FILE_ABS)' \
		'TOP_MODULE' '$(TOP_MODULE)' \
		'BD_NAME' '$(BD_NAME)' \
		'BD_TCL' '$(BD_TCL_ABS)' \
		'FPGA_FILELIST' '$(FPGA_FILELIST)' \
		'VERILOG_DEFINES' '$(EFFECTIVE_VERILOG_DEFINES)' \
		'FPGA_SYNTH_STRATEGY' '$(FPGA_SYNTH_STRATEGY)' \
		'FPGA_HW_TARGET_PATTERN' '$(FPGA_HW_TARGET_PATTERN)' \
		'FPGA_HW_TARGET_INDEX' '$(FPGA_HW_TARGET_INDEX)' \
		'FPGA_HW_FREQUENCY_HZ' '$(FPGA_HW_FREQUENCY_HZ)' \
		'FPGA_HW_DEVICE_PATTERN' '$(FPGA_HW_DEVICE_PATTERN)' \
		'FPGA_HW_AXI_NAME' '$(FPGA_HW_AXI_NAME)' \
		'JTAG_AXI_ADDR_WIDTH' '$(JTAG_AXI_ADDR_WIDTH)' \
		'JTAG_AXI_DATA_WIDTH' '$(JTAG_AXI_DATA_WIDTH)' \
		'JTAG_AXI_SANITY_ADDRESS' '$(JTAG_AXI_SANITY_ADDRESS)' \
		'UPLOAD_TRANSACTION_BYTES' '$(UPLOAD_TRANSACTION_BYTES)' \
		'BIOS_OFFSET' '$(BIOS_OFFSET)' \
		'KERNEL_OFFSET' '$(KERNEL_OFFSET)' \
		'LOADER_STATUS_OFFSET' '$(LOADER_STATUS_OFFSET)' \
		'LOADER_MAX_BYTES' '$(LOADER_MAX_BYTES)' \
		'LOADER_STACK_ADDR' '$(LOADER_STACK_ADDR)' \
		'LOADER_BOOTARGS' '$(LOADER_BOOTARGS)' \
		'UPLOAD_VERIFY' '$(UPLOAD_VERIFY)' \
		'UPLOAD_STATUS_ADDRESS' '$(UPLOAD_STATUS_ADDRESS)' \
		'UPLOAD_CPU_ACTION' '$(UPLOAD_CPU_ACTION)' \
		'VIVADO' '$(VIVADO)' \
		'PYTHON' '$(PYTHON)' \
		'VIVADO_JOBS' '$(VIVADO_JOBS)' \
		'VIVADO_THREADS' '$(VIVADO_THREADS)'

ips bd: project

project: $(PROJECT_FILE)

$(PROJECT_FILE):
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/create_project.tcl"

reproject:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/create_project.tcl"

rebuild:
	$(MAKE) -C "$(IMPL_DIR)" reproject
	$(MAKE) -C "$(IMPL_DIR)" bitstream

syn: $(PROJECT_FILE)
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/check_rtl.tcl"

synth check: syn

impl: $(PROJECT_FILE)
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/run_implementation.tcl"

bitstream: $(PROJECT_FILE)
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/build_bitstream.tcl"

FPGA_ILA_DEPTH ?= 1024
LA132_ILA_WORK_ROOT ?= xlnx-work-la132-ila
LA132_ILA_VERILOG_DEFINES := GODSON_DEBUG FPGA_LA132_BOOT_ILA
FPGA_LA132_CPU_ILA_DEPTH ?= 16384
FPGA_LA132_PIPE_ILA_DEPTH ?= 8192
FPGA_LA132_MMU_ILA_DEPTH ?= 8192
FPGA_LA132_AXI_ILA_DEPTH ?= 8192
FPGA_LA132_DCACHE_ILA_DEPTH ?= 4096

LA132_ILA_SUBMAKE = $(MAKE) -C "$(IMPL_DIR)" \
	BOARD='$(BOARD)' \
	WORK_ROOT='$(LA132_ILA_WORK_ROOT)' \
	PROJECT_DIR='$(LA132_ILA_WORK_ROOT)/$(PROJECT_NAME)' \
	VERILOG_DEFINES='$(LA132_ILA_VERILOG_DEFINES)'

bitstream-la132-ila:
	$(LA132_ILA_SUBMAKE) reproject
	$(LA132_ILA_SUBMAKE) _bitstream-la132-ila

_bitstream-la132-ila: $(PROJECT_FILE)
	env \
		FPGA_LA132_CPU_ILA_DEPTH='$(FPGA_LA132_CPU_ILA_DEPTH)' \
		FPGA_LA132_PIPE_ILA_DEPTH='$(FPGA_LA132_PIPE_ILA_DEPTH)' \
		FPGA_LA132_MMU_ILA_DEPTH='$(FPGA_LA132_MMU_ILA_DEPTH)' \
		FPGA_LA132_AXI_ILA_DEPTH='$(FPGA_LA132_AXI_ILA_DEPTH)' \
		FPGA_LA132_DCACHE_ILA_DEPTH='$(FPGA_LA132_DCACHE_ILA_DEPTH)' \
		$(VIVADO_BATCH) \
		-source "$(SCRIPT_DIR)/build_la132_boot_ila_bitstream.tcl"

status:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/report_project.tcl" -tclargs status

timing-syn:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/report_project.tcl" -tclargs synth

timing-impl:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/report_project.tcl" -tclargs impl

timing reports: timing-impl

# Upload the LA32 loader and Linux image to their physical board addresses.
BIOS_OFFSET ?= 0x1c000000
KERNEL_OFFSET ?= 0x00200000
LOADER_STATUS_OFFSET ?= 0x1c100000
LOADER_MAX_BYTES ?=
LOADER_STACK_ADDR ?= 0x12000000

UPLOAD_BUILD_TARGET := all
BIOS_ELE := loader/loader.bin
BIOS_FILE := bios.bin
KERNEL_ELF := loader/vmlinux.bin
KERNEL_FILE := vmlinux.ddr
UP_BIT_FILE := vmlinux.ddr.upload
UPLOAD_SEGMENTS := $(BIOS_OFFSET):$(BIOS_FILE) $(KERNEL_OFFSET):$(KERNEL_FILE)
UPLOAD_VERIFY_DEFAULT := sample
UPLOAD_STATUS_ADDRESS_DEFAULT := none

UPLOAD_VERIFY ?= $(UPLOAD_VERIFY_DEFAULT)
UPLOAD_STATUS_ADDRESS ?= $(UPLOAD_STATUS_ADDRESS_DEFAULT)
UPLOAD_CPU_ACTION ?= release
LOADER_BOOTARGS ?=

gen_ddr_data:
	$(MAKE) -C "$(IMPL_DIR)/loader" "$(UPLOAD_BUILD_TARGET)" \
		LOADER_BOOTARGS='$(LOADER_BOOTARGS)' \
		LOADER_STATUS_ADDR='$(LOADER_STATUS_OFFSET)' \
		LOADER_STACK_ADDR='$(LOADER_STACK_ADDR)'
	mkdir -p "$(WORK_ROOT_ABS)"
	rm -f -- "$(WORK_ROOT_ABS)/$(UP_BIT_FILE)" "$(WORK_ROOT_ABS)/$(BIOS_FILE)"
	cp "$(IMPL_DIR)/$(BIOS_ELE)" "$(WORK_ROOT_ABS)/$(BIOS_FILE)"
ifneq ($(strip $(LOADER_MAX_BYTES)),)
	@loader_bytes=$$(stat -c '%s' "$(WORK_ROOT_ABS)/$(BIOS_FILE)"); \
	if [ "$$loader_bytes" -gt "$(LOADER_MAX_BYTES)" ]; then \
		echo "Loader image is $$loader_bytes bytes; board limit is $(LOADER_MAX_BYTES) bytes" >&2; \
		exit 1; \
	fi
endif
ifneq ($(strip $(KERNEL_ELF)),)
	rm -f -- "$(WORK_ROOT_ABS)/$(KERNEL_FILE)"
	cp "$(IMPL_DIR)/$(KERNEL_ELF)" "$(WORK_ROOT_ABS)/$(KERNEL_FILE)"
endif
	cd "$(WORK_ROOT_ABS)" && $(PYTHON) "$(SCRIPT_DIR)/gen_upload_data.py" \
		"$(UP_BIT_FILE)" $(UPLOAD_SEGMENTS)

upload: gen_ddr_data
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/download_bit_ddr_and_run.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" "$(WORK_ROOT_ABS)/$(UP_BIT_FILE)" \
		"$(UPLOAD_VERIFY)" "$(UPLOAD_STATUS_ADDRESS)" "$(UPLOAD_CPU_ACTION)"

LA132_ILA_UPLOAD_CPU_ACTION ?= hold

upload-la132-ila:
	$(LA132_ILA_SUBMAKE) upload \
		UPLOAD_CPU_ACTION='$(LA132_ILA_UPLOAD_CPU_ACTION)'

cpu-reset:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/vio_cpu_reset.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" pulse 100

cpu-hold:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/vio_cpu_reset.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" assert

cpu-release:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/vio_cpu_reset.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" release

LSBD_STATUS_ILA_PREFIX ?= $(WORK_ROOT_ABS)/lsbd_status

capture-lsbd-status-ila:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/capture_lsbd_status_ila.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" "$(LSBD_STATUS_ILA_PREFIX)"

ILA_TIMEOUT_MINUTES ?= 3
ILA_KEEP_CPU_RUNNING ?= 0
ILA_TRIGGER_POSITION ?=

LA132_ILA_CAPTURE_PREFIX ?=
LA132_ILA_TIMEOUT_MINUTES ?= 1
ILA_CPU_TRIGGER_ADDRESS ?= 0x1c000058
ILA_PIPE_TRIGGER_ADDRESS ?= $(ILA_CPU_TRIGGER_ADDRESS)
ILA_MMU_TRIGGER_ADDRESS ?= 0xa0c5b084
ILA_AXI_TRIGGER_ADDRESS ?= 0xa0c5b090
ILA_DCACHE_TRIGGER_ADDRESS ?= 0xa0c210a4
ILA_FORCE_TRIGGER_DELAY_MS ?= 5000
ILA_TRIGGER_VALID ?= 1
ILA_WINDOW_COUNT ?= 1

capture-la132-ila:
	$(LA132_ILA_SUBMAKE) _capture-la132-ila

_capture-la132-ila:
	env \
		ILA_CPU_TRIGGER_ADDRESS='$(ILA_CPU_TRIGGER_ADDRESS)' \
		ILA_PIPE_TRIGGER_ADDRESS='$(ILA_PIPE_TRIGGER_ADDRESS)' \
		ILA_MMU_TRIGGER_ADDRESS='$(ILA_MMU_TRIGGER_ADDRESS)' \
		ILA_AXI_TRIGGER_ADDRESS='$(ILA_AXI_TRIGGER_ADDRESS)' \
		ILA_DCACHE_TRIGGER_ADDRESS='$(ILA_DCACHE_TRIGGER_ADDRESS)' \
		ILA_FORCE_TRIGGER_DELAY_MS='$(ILA_FORCE_TRIGGER_DELAY_MS)' \
		ILA_TRIGGER_POSITION='$(ILA_TRIGGER_POSITION)' \
		ILA_TRIGGER_VALID='$(ILA_TRIGGER_VALID)' \
		ILA_WINDOW_COUNT='$(ILA_WINDOW_COUNT)' \
		ILA_KEEP_CPU_RUNNING='$(ILA_KEEP_CPU_RUNNING)' \
		$(VIVADO_BATCH) \
		-source "$(SCRIPT_DIR)/capture_la132_boot_ila.tcl" \
		-tclargs "$(WORK_ROOT_ABS)" "$(LA132_ILA_CAPTURE_PREFIX)" \
			"$(LA132_ILA_TIMEOUT_MINUTES)"

diagnose-la132-boot:
	$(MAKE) -C "$(IMPL_DIR)" bitstream-la132-ila
	$(MAKE) -C "$(IMPL_DIR)" upload-la132-ila
	$(MAKE) -C "$(IMPL_DIR)" capture-la132-ila

JTAG_ADDR ?= $(LOADER_STATUS_OFFSET)
JTAG_LEN ?= 1
JTAG_DATA ?=

jtag-read:
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/jtag_axi_access.tcl" \
		-tclargs read "$(JTAG_ADDR)" "$(JTAG_LEN)"

jtag-write:
	@test -n "$(JTAG_DATA)" || { echo 'JTAG_DATA is required' >&2; exit 2; }
	$(VIVADO_BATCH) -source "$(SCRIPT_DIR)/jtag_axi_access.tcl" \
		-tclargs write "$(JTAG_ADDR)" "$(JTAG_DATA)" "$(JTAG_LEN)"


clean:
	@if [ -z "$(WORK_ROOT_ABS)" ] || \
		[ "$(WORK_ROOT_ABS)" = / ] || \
		[ "$(WORK_ROOT_ABS)" = "$(IMPL_DIR)" ]; then \
		echo "Refusing to remove unsafe WORK_ROOT=$(WORK_ROOT_ABS)" >&2; \
		exit 1; \
	fi
	rm -rf -- "$(WORK_ROOT_ABS)"
