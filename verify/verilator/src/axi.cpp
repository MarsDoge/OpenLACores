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

#include "Vverilator_top.h"
#include "sim.h"
#include <algorithm>

namespace openla132::sim {
namespace {

constexpr uint32_t CONSOLE_BASE = 0x9fe00000U;
constexpr uint32_t CONSOLE_SIZE = 4U;
constexpr uint32_t RT_MMIO_PHYS_BASE = 0x1fe00000U;
constexpr uint32_t RT_MMIO_VIRT_BASE = 0xbfe00000U;
constexpr uint32_t RT_MMIO_SIZE = 0x00100000U;
constexpr uint32_t RT_UART_OFFSET = 0x00000000U;
constexpr uint32_t RT_UART_SIZE = 0x20U;
constexpr uint32_t RT_LED_OFFSET = 0x0001f200U;
constexpr uint32_t RT_SIM_FLAG_OFFSET = 0x0001f300U;

bool in_range(uint32_t addr, uint32_t base, uint32_t size) {
  return addr >= base && addr - base < size;
}

bool rt_mmio_offset(uint32_t addr, uint32_t &offset) {
  if (in_range(addr, RT_MMIO_PHYS_BASE, RT_MMIO_SIZE)) {
    offset = addr - RT_MMIO_PHYS_BASE;
    return true;
  }
  if (in_range(addr, RT_MMIO_VIRT_BASE, RT_MMIO_SIZE)) {
    offset = addr - RT_MMIO_VIRT_BASE;
    return true;
  }
  return false;
}

} // namespace

// Constructs the AXI slave model with RAM and UART backends.
Axi::Axi(uint64_t ram_size, bool quiet_uart) : mem(ram_size), uart(quiet_uart) {}

// Resets pending AXI transactions and sampled handshakes.
void Axi::reset() {
  read_q.clear();
  for (auto &queue: write_q) {
    queue.clear();
  }
  for (auto &queue: wdata_q) {
    queue.clear();
  }
  bresp_q.clear();
  sampled = {};
  led_data = 0;
}

// Loads all image segments into the AXI-backed RAM.
void Axi::load(const Image &image) {
  for (const Segment &seg: image.segments) {
    mem.load(seg.addr, seg.data);
  }
}

// Drives AXI slave ready and response signals into the RTL model.
void Axi::drive(Vverilator_top &top) {
  top.arready = read_q.size() < QUEUE_SIZE;
  top.awready = aw_count() < QUEUE_SIZE;
  top.wready = w_count() < QUEUE_SIZE * 4;

  if (read_q.empty()) {
    top.rid = 0;
    top.rdata = 0;
    top.rresp = 0;
    top.rlast = 0;
    top.rvalid = 0;
  } else {
    Read &req = read_q.front();
    if (!req.ready) {
      read_beat(req);
      req.ready = true;
    }
    top.rid = req.id;
    top.rdata = req.data;
    top.rresp = req.resp;
    top.rlast = req.beat == req.len;
    top.rvalid = 1;
  }

  if (bresp_q.empty()) {
    top.bid = 0;
    top.bresp = 0;
    top.bvalid = 0;
  } else {
    top.bid = bresp_q.front().id;
    top.bresp = bresp_q.front().resp;
    top.bvalid = 1;
  }
}

// Samples AXI handshakes and payloads issued by the RTL model.
void Axi::sample(const Vverilator_top &top) {
  sampled = {};
  sampled.ar = top.arvalid && top.arready;
  sampled.r = top.rvalid && top.rready;
  sampled.aw = top.awvalid && top.awready;
  sampled.w = top.wvalid && top.wready;
  sampled.b = top.bvalid && top.bready;

  if (sampled.ar) {
    sampled.arid = top.arid;
    sampled.araddr = top.araddr;
    sampled.arlen = top.arlen;
    sampled.arsize = top.arsize;
    sampled.arburst = top.arburst;
  }
  if (sampled.aw) {
    sampled.awid = top.awid;
    sampled.awaddr = top.awaddr;
    sampled.awlen = top.awlen;
    sampled.awsize = top.awsize;
    sampled.awburst = top.awburst;
  }
  if (sampled.w) {
    sampled.wid = top.wid;
    sampled.wdata = top.wdata;
    sampled.wstrb = top.wstrb;
    sampled.wlast = top.wlast;
  }
}

// Advances AXI queues after a clock cycle.
void Axi::tick() {
  if (sampled.r && !read_q.empty()) {
    Read &req = read_q.front();
    if (req.beat == req.len) {
      read_q.pop_front();
    } else {
      req.addr = next_addr(req.addr, req.size, req.burst, req.len);
      req.beat++;
      req.ready = false;
    }
  }
  if (sampled.b && !bresp_q.empty()) {
    bresp_q.pop_front();
  }
  if (sampled.ar) {
    read_q.push_back({sampled.arid, sampled.araddr, sampled.arlen, sampled.arsize, sampled.arburst});
  }
  if (sampled.aw) {
    write_q[sampled.awid & 0xfU].push_back(
        {sampled.awid, sampled.awaddr, sampled.awlen, sampled.awsize, sampled.awburst});
  }
  if (sampled.w) {
    wdata_q[sampled.wid & 0xfU].push_back({sampled.wdata, sampled.wstrb, sampled.wlast});
  }
  drain_writes();
}

// Returns read-only access to the AXI-backed RAM.
const Ram &Axi::ram() const {
  return mem;
}

// Returns writable access to the AXI-backed RAM.
Ram &Axi::ram() {
  return mem;
}

// Reports whether an address belongs to a simulator peripheral aperture.
bool Axi::device_hit(uint32_t addr) const {
  uint32_t offset = 0;
  return in_range(addr, CONSOLE_BASE, CONSOLE_SIZE) || rt_mmio_offset(addr, offset);
}

// Reports whether an address reads the UART receive-data register.
bool Axi::is_uart_rx_read(uint32_t addr) const {
  uint32_t offset = 0;
  return rt_mmio_offset(addr, offset) && in_range(offset, RT_UART_OFFSET, RT_UART_SIZE)
         && uart.is_rx_data_read(offset - RT_UART_OFFSET);
}

// Reads the aligned 32-bit word containing a local-SRAM device address.
uint32_t Axi::read_device(uint32_t addr, bool consume_rx) {
  uint32_t base = addr & ~0x3U;
  uint32_t data = 0;
  for (unsigned lane = 0; lane < 4; lane++) {
    uint8_t byte = 0;
    read_device8(base + lane, byte, consume_rx);
    data |= static_cast<uint32_t>(byte) << (lane * 8U);
  }
  return data;
}

// Removes the byte returned by a deferred UART receive-data read.
void Axi::consume_uart_rx(uint32_t addr) {
  uint32_t offset = 0;
  if (rt_mmio_offset(addr, offset) && in_range(offset, RT_UART_OFFSET, RT_UART_SIZE)) {
    uart.consume_rx_data(offset - RT_UART_OFFSET);
  }
}

// Applies one local-SRAM device write using the CPU byte strobes.
void Axi::write_device(uint32_t addr, uint32_t data, uint8_t strb) {
  uint32_t base = addr & ~0x3U;
  for (unsigned lane = 0; lane < 4; lane++) {
    if (strb & (1U << lane)) {
      write_device8(base + lane, static_cast<uint8_t>(data >> (lane * 8U)));
    }
  }
}

// Injects one host-terminal character into the shared UART model.
void Axi::receive_uart(uint8_t data) {
  uart.receive(data);
}

// Computes the address of the next AXI burst beat.
uint32_t Axi::next_addr(uint32_t addr, uint8_t size, uint8_t burst, uint8_t len) {
  if (burst == 0) {
    return addr;
  }
  uint32_t bytes = size < 31 ? 1U << size : 0;
  if (!bytes) {
    return addr;
  }
  uint32_t next = addr + bytes;
  if (burst != 2) {
    return next;
  }
  uint32_t span = bytes * (static_cast<uint32_t>(len) + 1U);
  if (!span || (span & (span - 1U))) {
    return next;
  }
  uint32_t base = addr & ~(span - 1U);
  return next >= base + span ? base : next;
}

// Produces one AXI read-data beat.
uint8_t Axi::read_beat(Read &req) {
  req.data = 0;
  req.resp = 0;
  if (req.size > 2) {
    return req.resp = 2;
  }

  unsigned bytes = 1U << req.size;
  unsigned lane = req.addr & 0x3U;
  if (lane + bytes > 4) {
    return req.resp = 2;
  }
  for (unsigned index = 0; index < bytes; index++) {
    uint8_t data = read8(req.addr + index, req.resp);
    req.data |= static_cast<uint32_t>(data) << ((lane + index) * 8U);
  }
  return req.resp;
}

// Applies one AXI write-data beat.
uint8_t Axi::write_beat(const Write &req, const WData &data) {
  uint8_t resp = 0;
  uint32_t addr = req.addr & ~0x3U;
  for (unsigned lane = 0; lane < 4; lane++) {
    if (!(data.strb & (1U << lane))) {
      continue;
    }
    write8(addr + lane, static_cast<uint8_t>(data.data >> (lane * 8U)), resp);
  }
  return resp;
}

// Reads one byte from the shared simulator peripheral map.
bool Axi::read_device8(uint32_t addr, uint8_t &data, bool consume_rx) {
  uint32_t offset = 0;
  if (rt_mmio_offset(addr, offset)) {
    if (in_range(offset, RT_UART_OFFSET, RT_UART_SIZE)) {
      data = uart.read((offset - RT_UART_OFFSET), consume_rx);
    } else if (in_range(offset, RT_LED_OFFSET, sizeof(led_data))) {
      data = static_cast<uint8_t>(led_data >> ((offset - RT_LED_OFFSET) * 8U));
    } else if (in_range(offset, RT_SIM_FLAG_OFFSET, sizeof(uint32_t))) {
      data = offset == RT_SIM_FLAG_OFFSET ? 1U : 0U;
    } else {
      data = 0;
    }
    return true;
  }
  if (in_range(addr, CONSOLE_BASE, CONSOLE_SIZE)) {
    data = 0;
    return true;
  }
  return false;
}

// Writes one byte to the shared simulator peripheral map.
bool Axi::write_device8(uint32_t addr, uint8_t data) {
  if (in_range(addr, CONSOLE_BASE, CONSOLE_SIZE)) {
    uart.write_console(data);
    return true;
  }
  uint32_t offset = 0;
  if (rt_mmio_offset(addr, offset)) {
    if (in_range(offset, RT_UART_OFFSET, RT_UART_SIZE)) {
      uart.write((offset - RT_UART_OFFSET), data);
    } else if (in_range(offset, RT_LED_OFFSET, sizeof(led_data))) {
      unsigned shift = (offset - RT_LED_OFFSET) * 8U;
      led_data = (led_data & ~(0xffU << shift)) | (static_cast<uint32_t>(data) << shift);
    }
    return true;
  }
  return false;
}

// Reads one byte from the AXI address space.
uint8_t Axi::read8(uint32_t addr, uint8_t &resp) {
  uint8_t data = 0;
  if (read_device8(addr, data)) {
    return data;
  }
  if (mem.valid(addr)) {
    return mem.read8(addr);
  }
  resp = std::max<uint8_t>(resp, 3);
  return 0;
}

// Writes one byte to the AXI address space.
void Axi::write8(uint32_t addr, uint8_t data, uint8_t &resp) {
  if (write_device8(addr, data)) {
    return;
  }
  if (mem.valid(addr)) {
    mem.write8(addr, data);
    return;
  }
  resp = std::max<uint8_t>(resp, 3);
}

// Matches queued AXI write addresses with write-data beats.
void Axi::drain_writes() {
  for (unsigned id = 0; id < write_q.size(); id++) {
    auto &requests = write_q[id];
    auto &data = wdata_q[id];
    while (!requests.empty() && !data.empty()) {
      Write &req = requests.front();
      WData beat = data.front();
      data.pop_front();

      req.resp = std::max(req.resp, write_beat(req, beat));
      bool last = req.beat == req.len;
      if (beat.last != last) {
        req.resp = std::max<uint8_t>(req.resp, 2);
      }
      if (beat.last || last) {
        bresp_q.push_back({req.id, req.resp});
        requests.pop_front();
      } else {
        req.addr = next_addr(req.addr, req.size, req.burst, req.len);
        req.beat++;
      }
    }
  }
}

// Counts queued AXI write-address requests.
size_t Axi::aw_count() const {
  size_t count = 0;
  for (const auto &queue: write_q) {
    count += queue.size();
  }
  return count;
}

// Counts queued AXI write-data beats.
size_t Axi::w_count() const {
  size_t count = 0;
  for (const auto &queue: wdata_q) {
    count += queue.size();
  }
  return count;
}

} // namespace openla132::sim
