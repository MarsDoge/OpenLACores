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
#include <stdexcept>

namespace openla132::sim {

// Constructs a sparse, demand-paged RAM model.
Ram::Ram(uint64_t size) : size(size) {}

// Checks whether a memory range is fully contained in RAM.
bool Ram::valid(uint64_t addr, size_t len) const {
  return len && addr < size && len <= size - addr;
}

// Reads one byte from sparse RAM.
uint8_t Ram::read8(uint32_t addr) const {
  if (!valid(addr)) {
    throw std::out_of_range("memory read outside configured RAM");
  }
  const Page *page = find_page(addr);
  return page ? (*page)[addr & (PAGE_SIZE - 1U)] : 0;
}

// Reads a 32-bit little-endian value from RAM.
uint32_t Ram::read32(uint32_t addr) const {
  if (!valid(addr, 4)) {
    return 0;
  }
  uint32_t data = 0;
  for (unsigned index = 0; index < 4; index++) {
    data |= static_cast<uint32_t>(read8(addr + index)) << (index * 8U);
  }
  return data;
}

// Writes one byte to sparse RAM.
void Ram::write8(uint32_t addr, uint8_t data) {
  if (!valid(addr)) {
    throw std::out_of_range("memory write outside configured RAM");
  }
  new_page(addr)[addr & (PAGE_SIZE - 1U)] = data;
}

// Loads an image segment into RAM.
void Ram::load(uint32_t addr, const std::vector<uint8_t> &data) {
  if (data.empty()) {
    return;
  }
  if (!valid(addr, data.size())) {
    throw std::runtime_error("program segment is outside configured RAM");
  }
  for (size_t index = 0; index < data.size(); index++) {
    write8(addr + static_cast<uint32_t>(index), data[index]);
  }
}

// Finds the allocated RAM page containing an address.
const Ram::Page *Ram::find_page(uint32_t addr) const {
  auto it = page_map.find(addr >> PAGE_BITS);
  return it == page_map.end() ? nullptr : it->second.get();
}

// Returns or allocates the writable RAM page containing an address.
Ram::Page &Ram::new_page(uint32_t addr) {
  uint32_t index = addr >> PAGE_BITS;
  auto [it, inserted] = page_map.try_emplace(index);
  if (inserted) {
    it->second = std::make_unique<Page>();
    it->second->fill(0);
  }
  return *it->second;
}

} // namespace openla132::sim
