#
# Copyright (c) 2026 Loongson Technology Corporation Limited. 
#
# OpenLACores is licensed under Mulan PSL v2.
#
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# 
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#

PROJECT_NAME ?= openla132s_lsbd_bd
WORK_ROOT ?= xlnx-work-lsbd
PROJECT_DIR ?= $(WORK_ROOT)/$(PROJECT_NAME)

FPGA_PART ?= xc7a200t-fbg676-2
# The CPU clock is independently configurable; the fabric and MIG UI remain
# fixed at 100 MHz behind the asynchronous AXI Clock Converter.
CPU_FREQ_HZ ?= 50000000
CONSTRAINT_FILE ?= constraints/lsbd.xdc
TOP_FILE ?= soc/xlnx_soc_lsbd_bd.v
TOP_MODULE ?= $(basename $(notdir $(TOP_FILE)))
BD_NAME ?= xlnx_lsbd_peripherals_bd
BD_TCL ?= bd/xlnx_soc_lsbd_peripherals_bd.tcl
VERILOG_DEFINES ?=
FPGA_FILELIST ?= openla132.f
FPGA_SYNTH_STRATEGY ?= Flow_PerfOptimized_high

FPGA_HW_TARGET_PATTERN ?= */xilinx_tcf/Digilent/*
FPGA_HW_TARGET_INDEX ?= 0
FPGA_HW_FREQUENCY_HZ ?= 15000000
FPGA_HW_DEVICE_PATTERN ?= xc7a200t_0
FPGA_HW_AXI_NAME ?= hw_axi_1
JTAG_AXI_ADDR_WIDTH ?= 32
JTAG_AXI_DATA_WIDTH ?= 32
JTAG_AXI_SANITY_ADDRESS ?= 0x07fff000
UPLOAD_TRANSACTION_BYTES ?= 1024

BIOS_OFFSET ?= 0x1c000000
LOADER_STATUS_OFFSET ?= 0x1c000fc0
LOADER_MAX_BYTES ?= 4032
LOADER_STACK_ADDR ?= 0x07f00000
LOADER_BOOTARGS ?= mem=128M
JTAG_ADDR ?= $(LOADER_STATUS_OFFSET)
