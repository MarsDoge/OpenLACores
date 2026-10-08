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

// Compares the DUT and reference PCs for one commit.
std::string check_pc(const Commit &commit, const la_ref_state_t &ref) {
  if (static_cast<uint32_t>(ref.pc) == commit.pc) {
    return {};
  }
  std::ostringstream out;
  out << "commit PC mismatch: DUT=0x" << std::hex << std::setw(8) << std::setfill('0') << commit.pc << " REF=0x"
      << std::setw(8) << static_cast<uint32_t>(ref.pc);
  return out.str();
}

// Compares DUT and reference general-purpose registers.
std::string check_gpr(const std::array<uint32_t, 32> &dut, const la_ref_state_t &ref) {
  std::ostringstream out;
  unsigned errors = 0;
  for (unsigned index = 0; index < dut.size(); index++) {
    uint32_t expected = static_cast<uint32_t>(ref.xrf.value[index]);
    if (dut[index] == expected) {
      continue;
    }
    if (!errors) {
      out << "GPR mismatch after commit:";
    }
    out << "\n  r" << std::dec << std::setw(2) << std::setfill(' ') << index << " DUT=0x" << std::hex << std::setw(8)
        << std::setfill('0') << dut[index] << " REF=0x" << std::setw(8) << expected;
    if (++errors == 8) {
      out << "\n  (additional mismatches omitted)";
      break;
    }
  }
  return out.str();
}

} // namespace openla132::sim
