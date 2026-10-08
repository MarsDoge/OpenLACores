OPEN132_MMU_RTL_SRCS := \
	design/sys/openla132/mmu/mmu_tlb_entry.v \
	design/sys/openla132/mmu/mmu_tlb.v \
	design/sys/openla132/mmu/mmu_ptw.v \
	design/sys/openla132/mmu/mmu_port.v \
	design/sys/openla132/mmu/mmu_core.v \
	design/sys/openla132/mmu/mmu_dcache_arb.v
OPEN132_MMU_TB := verify/la132/mmu/tb_la132_mmu_core.v
OPEN132_MMU_PORT_KILL_TB := verify/la132/mmu/tb_la132_mmu_port_kill.v
OPEN132_LSU_STOREQ_RTL_SRCS := \
	design/sys/openla132/mmu/mmu_vaddr_to_paddr.v \
	design/sys/openla132/mmu/mmu_vaddr_sel_bus.v \
	design/sys/openla132/mmu/mmu_mpu.v \
	design/sys/openla132/rtu/rtu_expt_entry.v \
	design/sys/openla132/csr/csr_stall_chk.v \
	design/sys/openla132/csr/csr_cpucfg.v \
	design/sys/openla132/csr/csr_regs.v \
	design/sys/openla132/lsu/lsu_stage.v
OPEN132_LSU_STOREQ_TB := verify/la132/mmu/tb_la132_lsu_storeq_flush.v
OPEN132_CACHE_XLAT_SIDEBAND_TB := verify/la132/mmu/tb_la132_cache_xlat_sideband.v
CONFIG_MMU ?= 1
CONFIG_MMU_RESOLVED := $(strip $(CONFIG_MMU))
CONFIG_MMU_SUPPORTED := 0 1
ifneq ($(words $(CONFIG_MMU_RESOLVED)),1)
$(error CONFIG_MMU must be exactly one integer from: $(CONFIG_MMU_SUPPORTED))
endif
ifeq ($(filter $(CONFIG_MMU_RESOLVED),$(CONFIG_MMU_SUPPORTED)),)
$(error CONFIG_MMU must be one of: $(CONFIG_MMU_SUPPORTED); got '$(CONFIG_MMU)')
endif
OPEN132_DUT_VDEFINES := $(if $(filter 1,$(CONFIG_MMU_RESOLVED)),+define+CONFIG_MMU,)
OPEN132_MMU_CPPFLAGS := -DCONFIG_MMU -Idesign/sys/openla132/include

.PHONY: openla132-emu la132-test-mmu clean

openla132-emu:
	$(MAKE) -C verify/difftest la132-emu DUT_VDEFINES='$(OPEN132_DUT_VDEFINES)'

la132-test-mmu:
	@mkdir -p build/la132/tests
	iverilog -g2005 -Wall -Wno-timescale \
		$(OPEN132_MMU_CPPFLAGS) -s tb_la132_mmu_core \
		-o build/la132/tests/mmu-core.vvp \
		$(OPEN132_MMU_RTL_SRCS) $(OPEN132_MMU_TB)
	vvp build/la132/tests/mmu-core.vvp | \
		tee build/la132/tests/mmu-core.log
	@rg -q '^PASS tb_la132_mmu_core$$' build/la132/tests/mmu-core.log
	@! rg -q '^FAIL' build/la132/tests/mmu-core.log
	iverilog -g2005 -Wall -Wno-timescale \
		$(OPEN132_MMU_CPPFLAGS) -s tb_la132_mmu_port_kill \
		-o build/la132/tests/mmu-port-kill.vvp \
		design/sys/openla132/mmu/mmu_port.v $(OPEN132_MMU_PORT_KILL_TB)
	vvp build/la132/tests/mmu-port-kill.vvp | \
		tee build/la132/tests/mmu-port-kill.log
	@rg -q '^PASS tb_la132_mmu_port_kill$$' build/la132/tests/mmu-port-kill.log
	@! rg -q '^FAIL' build/la132/tests/mmu-port-kill.log
	iverilog -g2005 -Wall -Wno-timescale \
		$(OPEN132_MMU_CPPFLAGS) -s tb_la132_lsu_storeq_flush \
		-o build/la132/tests/lsu-storeq-flush.vvp \
		$(OPEN132_LSU_STOREQ_RTL_SRCS) $(OPEN132_LSU_STOREQ_TB)
	vvp build/la132/tests/lsu-storeq-flush.vvp | \
		tee build/la132/tests/lsu-storeq-flush.log
	@rg -q '^PASS tb_la132_lsu_storeq_flush$$' build/la132/tests/lsu-storeq-flush.log
	@! rg -q '^FAIL' build/la132/tests/lsu-storeq-flush.log
	iverilog -g2005 -Wall -Wno-timescale -Wno-portbind \
		-DCONFIG_MMU -s tb_la132_cache_xlat_sideband \
		-o build/la132/tests/cache-xlat-sideband.vvp \
		-f design/filelist/openla132.f $(OPEN132_CACHE_XLAT_SIDEBAND_TB)
	vvp build/la132/tests/cache-xlat-sideband.vvp | \
		tee build/la132/tests/cache-xlat-sideband.log
	@rg -q '^PASS tb_la132_cache_xlat_sideband$$' build/la132/tests/cache-xlat-sideband.log
	@! rg -q '^FAIL' build/la132/tests/cache-xlat-sideband.log

clean:
	$(MAKE) -C verify/difftest clean
	rm -rf build/la132/tests
