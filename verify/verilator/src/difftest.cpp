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
#include <iomanip>
#include <sstream>

namespace openla132::sim {

// Initializes difftest with the program image, reset state, and CPU policy.
DiffTest::DiffTest(const SimArgs &args, const Image &image, uint32_t pc)
    : ref(args.ref, args.ref_arch, args.ram_size), cpu(make_diff_micro(args.cpu)) {
  for (const Segment &seg: image.segments) {
    ref.memcpy_to_ref(seg.addr, seg.data.data(), seg.data.size());
  }

  la_ref_state_t regs = ref.regs();
  for (uint32_t index = 0; index < 32U; ++index) {
    regs.xrf.value[index] = 0;
  }
  regs.pc = pc;
  ref.set_regs(regs);
  cpu->init(ref, pc);
  ref_state = ref.regs();
}

// Passes an RTL state snapshot to the CPU difftest policy.
void DiffTest::observe(const DiffState &state) {
  cpu->observe(state);
}

// Samples RTL internal signals required by the CPU difftest policy.
void DiffTest::sample(const Vverilator_top &top) {
  cpu->sample(top);
}

// Detects a commit whose reference execution must be skipped for MMIO.
bool DiffTest::is_mmio(const Vverilator_top &top) const {
  return cpu->is_mmio(top);
}

// Returns the instruction associated with a committed PC.
uint32_t DiffTest::instruction(uint32_t pc, uint32_t fallback) const {
  return cpu->instruction(pc, fallback);
}

// Compares one DUT commit against the reference model.
bool DiffTest::step(const Commit &commit) {
  nr_commit++;
  recent.push_back(commit);
  if (recent.size() > 16) {
    recent.pop_front();
  }

  cpu->sync(ref, ref_state);
  error = check_pc(commit, ref_state);
  if (!error.empty()) {
    if (cpu->fix_pc(commit, ref, ref_state)) {
      error = check_pc(commit, ref_state);
    }
    if (!error.empty()) {
      error += dump_recent();
      return false;
    }
  }

  if (commit.wen && commit.wdest) {
    gpr[commit.wdest] = commit.wdata;
  }
  gpr[0] = 0;

  DiffAction action = cpu->before_exec(commit, gpr, error);
  if (action == DiffAction::Fail) {
    error += dump_recent();
    return false;
  }
  if (action == DiffAction::Skip) {
    return true;
  }

  if (commit.mmio) {
    ref_state.pc = commit.pc + 4U;
    if (commit.wen && commit.wdest) {
      ref_state.xrf.value[commit.wdest] = commit.wdata;
    }
    ref.set_regs(ref_state);
    cpu->after_commit(ref, ref_state);
    return true;
  }

  ref.exec(1);
  ref_state = ref.regs();
  cpu->after_exec(commit, gpr, ref, ref_state);
  error = check_gpr(gpr, ref_state);
  if (!error.empty()) {
    std::ostringstream out;
    out << "\ncommit #" << nr_commit << " pc=0x" << std::hex << std::setw(8) << std::setfill('0') << commit.pc
        << " inst=0x" << std::setw(8) << commit.inst;
    error += out.str();
    error += dump_recent();
    return false;
  }
  cpu->after_commit(ref, ref_state);
  return true;
}

// Returns the diagnostic text for the latest difftest failure.
const std::string &DiffTest::last_error() const {
  return error;
}

// Formats recent DUT commits for diagnostics.
std::string DiffTest::dump_recent() const {
  std::ostringstream out;
  out << "\nrecent DUT commits:";
  uint64_t first = nr_commit >= recent.size() ? nr_commit - recent.size() + 1 : 1;
  for (const Commit &commit: recent) {
    out << "\n  #" << std::dec << first++ << " pc=0x" << std::hex << std::setw(8) << std::setfill('0') << commit.pc
        << " inst=0x" << std::setw(8) << commit.inst;
    if (commit.wen) {
      out << " r" << std::dec << static_cast<unsigned>(commit.wdest) << "=0x" << std::hex << std::setw(8)
          << commit.wdata;
    }
    if (commit.cancel) {
      out << " cancel";
    }
    if (commit.mmio) {
      out << " mmio";
    }
  }
  return out.str();
}

} // namespace openla132::sim
