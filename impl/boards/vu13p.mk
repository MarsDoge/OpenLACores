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

PROJECT_NAME ?= openla132s_xlnx_bd
WORK_ROOT ?= xlnx-work-vu13p
PROJECT_DIR ?= $(WORK_ROOT)/$(PROJECT_NAME)

FPGA_PART ?= xcvu13p-fhgb2104-2-i
CPU_FREQ_HZ ?= 100000000
CONSTRAINT_FILE ?= constraints/axvu13p.xdc
TOP_FILE ?= soc/xlnx_soc_vu13p_bd.v
TOP_MODULE ?= $(basename $(notdir $(TOP_FILE)))
BD_NAME ?= xlnx_soc_peripherals_bd
BD_TCL ?= bd/xlnx_soc_peripherals_bd.tcl
VERILOG_DEFINES ?=
FPGA_FILELIST ?= openla132.f
FPGA_SYNTH_STRATEGY ?= Flow_PerfOptimized_high

FPGA_HW_TARGET_PATTERN ?= */xilinx_tcf/Digilent/*
FPGA_HW_TARGET_INDEX ?= 0
FPGA_HW_FREQUENCY_HZ ?= 15000000
FPGA_HW_DEVICE_PATTERN ?= xcvu13p_0
FPGA_HW_AXI_NAME ?= hw_axi_1
JTAG_AXI_ADDR_WIDTH ?= 64
JTAG_AXI_DATA_WIDTH ?= 64
JTAG_AXI_SANITY_ADDRESS ?= 0x1efff000
UPLOAD_TRANSACTION_BYTES ?= 1024
