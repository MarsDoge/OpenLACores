// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

#include "sim.h"
#include <cstdlib>
#include <dlfcn.h>
#include <stdexcept>

namespace openla132::sim {
namespace {

// Resolves a difftest interface symbol from the reference-model library.
template <typename T> T load_sym(void *so, const char *name, bool required = true) {
  dlerror();
  void *sym = dlsym(so, name);
  const char *error = dlerror();
  if (error && required) {
    throw std::runtime_error(std::string("reference model lacks ") + name + ": " + error);
  }
  return error ? nullptr : reinterpret_cast<T>(sym);
}

} // namespace

// Loads and initializes the reference-model shared library.
Ref::Ref(const std::string &so_file, const std::string &arch, uint64_t ram_size) {
  if (setenv("LOONG64_EMU_REF_ARCH", arch.c_str(), 1)) {
    throw std::runtime_error("cannot select reference architecture");
  }
  so = dlopen(so_file.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!so) {
    throw std::runtime_error("cannot load reference model " + so_file + ": " + dlerror());
  }

  try {
    auto set_ram_size = load_sym<SetRamSizeFn>(so, "difftest_set_ramsize");
    auto init_v2 = load_sym<InitV2Fn>(so, "difftest_init_v2", false);
    auto init = load_sym<InitFn>(so, "difftest_init", !init_v2);
    memcpy_fn = load_sym<MemcpyFn>(so, "difftest_memcpy");
    regcpy_fn = load_sym<RegcpyFn>(so, "difftest_regcpy");
    csrcpy_fn = load_sym<CsrcpyFn>(so, "difftest_csrcpy_idx");
    tlbcpy_fn = load_sym<TlbcpyFn>(so, "difftest_tlbcpy");
    exec_fn = load_sym<ExecFn>(so, "difftest_exec");
    close_fn = load_sym<CloseFn>(so, "difftest_close", false);

    set_ram_size(static_cast<size_t>(ram_size));
    if (init_v2) {
      init_v2(sizeof(la_ref_state_t));
    } else {
      init();
    }
  } catch (...) {
    dlclose(so);
    so = nullptr;
    throw;
  }
}

// Releases the reference-model shared library and its resources.
Ref::~Ref() {
  if (!so) {
    return;
  }
  if (close_fn) {
    close_fn();
  }
  dlclose(so);
}

// Copies host memory into reference-model memory.
void Ref::memcpy_to_ref(uint64_t addr, const void *data, size_t size) {
  if (size) {
    memcpy_fn(addr, const_cast<void *>(data), size, true);
  }
}

// Copies reference-model memory into a host buffer.
void Ref::memcpy_from_ref(uint64_t addr, void *data, size_t size) const {
  if (size) {
    memcpy_fn(addr, data, size, false);
  }
}

// Writes a complete register state to the reference model.
void Ref::set_regs(const la_ref_state_t &regs) {
  la_ref_state_t copy = regs;
  regcpy_fn(&copy, true, false);
}

// Reads the complete register state from the reference model.
la_ref_state_t Ref::regs() const {
  la_ref_state_t regs{};
  regcpy_fn(&regs, false, false);
  return regs;
}

// Updates one reference-model CSR with a mask.
void Ref::set_csr(uint32_t index, uint64_t value, uint64_t mask) {
  csrcpy_fn(static_cast<int>(index), &value, mask, true);
}

// Reads one CSR from the reference model.
uint64_t Ref::get_csr(uint32_t index) const {
  uint64_t value = 0;
  csrcpy_fn(static_cast<int>(index), &value, ~0ULL, false);
  return value;
}

// Writes a complete TLB state to the reference model.
void Ref::set_tlb(const la_tlb_state_t &tlb) {
  la_tlb_state_t copy = tlb;
  tlbcpy_fn(&copy, true);
}

// Reads the complete TLB state from the reference model.
la_tlb_state_t Ref::get_tlb() const {
  la_tlb_state_t tlb{};
  tlbcpy_fn(&tlb, false);
  return tlb;
}

// Executes the requested number of instructions in the reference model.
void Ref::exec(uint64_t count) {
  exec_fn(count);
}

} // namespace openla132::sim
