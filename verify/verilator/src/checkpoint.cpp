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
#include "verilated.h"
#include "verilated_save.h"
#include <algorithm>
#include <array>
#include <filesystem>
#include <stdexcept>
#include <system_error>

namespace openla132::sim {
namespace {

constexpr uint64_t CHECKPOINT_MAGIC = 0x4f4c413133324350ULL;
constexpr uint32_t CHECKPOINT_VERSION = 2;
constexpr uint64_t MAX_QUEUE = 1ULL << 20U;

// Reads and bounds-checks a checkpoint container length.
uint64_t read_count(VerilatedDeserialize &in, uint64_t max, const char *name) {
  uint64_t count = 0;
  in >> count;
  if (count > max) {
    throw std::runtime_error(std::string("invalid checkpoint ") + name + " count");
  }
  return count;
}

// Serializes one DUT commit record.
void save_commit(VerilatedSerialize &out, const Commit &commit) {
  out << commit.pc << commit.inst << commit.wdata << commit.wdest << commit.wen << commit.cancel;
}

// Restores one DUT commit record from a checkpoint.
void load_commit(VerilatedDeserialize &in, Commit &commit) {
  in >> commit.pc >> commit.inst >> commit.wdata >> commit.wdest >> commit.wen >> commit.cancel;
}

} // namespace

// Returns the allocated RAM page base addresses in stable order.
std::vector<uint32_t> Ram::pages() const {
  std::vector<uint32_t> list;
  list.reserve(page_map.size());
  for (const auto &item: page_map) {
    list.push_back(item.first << PAGE_BITS);
  }
  std::sort(list.begin(), list.end());
  return list;
}

// Saves allocated RAM pages to a checkpoint.
void Ram::save(VerilatedSerialize &out) const {
  out << size << static_cast<uint64_t>(page_map.size());
  for (uint32_t addr: pages()) {
    out << (addr >> PAGE_BITS);
    out.write(find_page(addr)->data(), PAGE_SIZE);
  }
}

// Restores RAM pages from a checkpoint.
void Ram::load(VerilatedDeserialize &in) {
  uint64_t saved_size = 0;
  in >> saved_size;
  if (saved_size != size) {
    throw std::runtime_error("checkpoint RAM size does not match --ram-size");
  }

  uint64_t max_pages = (size + PAGE_SIZE - 1U) >> PAGE_BITS;
  uint64_t count = read_count(in, max_pages, "memory page");
  page_map.clear();
  for (uint64_t index = 0; index < count; index++) {
    uint32_t page_index = 0;
    in >> page_index;
    uint64_t addr = static_cast<uint64_t>(page_index) << PAGE_BITS;
    if (addr >= size) {
      throw std::runtime_error("checkpoint contains a RAM page outside --ram-size");
    }
    Page &page = new_page(static_cast<uint32_t>(addr));
    in.read(page.data(), page.size());
  }
}

// Saves UART registers and transmit/receive buffers.
void Uart::save(VerilatedSerialize &out) const {
  out << dll << dlm << ier << lcr << mcr << scr;
  out << static_cast<uint64_t>(rx.size());
  for (uint8_t data: rx) {
    out << data;
  }
  out << tx;
}

// Restores UART registers and transmit/receive buffers.
void Uart::load(VerilatedDeserialize &in) {
  in >> dll >> dlm >> ier >> lcr >> mcr >> scr;
  uint64_t count = read_count(in, MAX_QUEUE, "UART receive");
  rx.clear();
  for (uint64_t index = 0; index < count; index++) {
    uint8_t data = 0;
    in >> data;
    rx.push_back(data);
  }
  in >> tx;
}

// Saves AXI devices and outstanding transactions.
void Axi::save(VerilatedSerialize &out) const {
  auto save_read = [&out](const Read &req) {
    out << req.id << req.addr << req.len << req.size << req.burst << req.beat << req.data << req.resp << req.ready;
  };
  auto save_write = [&out](const Write &req) {
    out << req.id << req.addr << req.len << req.size << req.burst << req.beat << req.resp;
  };
  auto save_wdata = [&out](const WData &data) { out << data.data << data.strb << data.last; };

  mem.save(out);
  uart.save(out);
  out << led_data;
  out << static_cast<uint64_t>(read_q.size());
  for (const Read &req: read_q) {
    save_read(req);
  }
  for (const auto &queue: write_q) {
    out << static_cast<uint64_t>(queue.size());
    for (const Write &req: queue) {
      save_write(req);
    }
  }
  for (const auto &queue: wdata_q) {
    out << static_cast<uint64_t>(queue.size());
    for (const WData &data: queue) {
      save_wdata(data);
    }
  }
  out << static_cast<uint64_t>(bresp_q.size());
  for (const BResp &resp: bresp_q) {
    out << resp.id << resp.resp;
  }
  out << sampled.ar << sampled.r << sampled.aw << sampled.w << sampled.b << sampled.arid << sampled.araddr
      << sampled.arlen << sampled.arsize << sampled.arburst << sampled.awid << sampled.awaddr << sampled.awlen
      << sampled.awsize << sampled.awburst << sampled.wid << sampled.wdata << sampled.wstrb << sampled.wlast;
}

// Restores AXI devices and outstanding transactions.
void Axi::load(VerilatedDeserialize &in) {
  auto load_read = [&in](Read &req) {
    in >> req.id >> req.addr >> req.len >> req.size >> req.burst >> req.beat >> req.data >> req.resp >> req.ready;
  };
  auto load_write = [&in](Write &req) {
    in >> req.id >> req.addr >> req.len >> req.size >> req.burst >> req.beat >> req.resp;
  };
  auto load_wdata = [&in](WData &data) { in >> data.data >> data.strb >> data.last; };

  mem.load(in);
  uart.load(in);
  in >> led_data;
  read_q.clear();
  uint64_t reads = read_count(in, MAX_QUEUE, "AXI read");
  for (uint64_t index = 0; index < reads; index++) {
    Read req{};
    load_read(req);
    read_q.push_back(req);
  }
  for (auto &queue: write_q) {
    queue.clear();
    uint64_t count = read_count(in, MAX_QUEUE, "AXI write");
    for (uint64_t index = 0; index < count; index++) {
      Write req{};
      load_write(req);
      queue.push_back(req);
    }
  }
  for (auto &queue: wdata_q) {
    queue.clear();
    uint64_t count = read_count(in, MAX_QUEUE, "AXI write data");
    for (uint64_t index = 0; index < count; index++) {
      WData data{};
      load_wdata(data);
      queue.push_back(data);
    }
  }
  bresp_q.clear();
  uint64_t responses = read_count(in, MAX_QUEUE, "AXI write response");
  for (uint64_t index = 0; index < responses; index++) {
    BResp resp{};
    in >> resp.id >> resp.resp;
    bresp_q.push_back(resp);
  }
  in >> sampled.ar >> sampled.r >> sampled.aw >> sampled.w >> sampled.b >> sampled.arid >> sampled.araddr >>
      sampled.arlen >> sampled.arsize >> sampled.arburst >> sampled.awid >> sampled.awaddr >> sampled.awlen >>
      sampled.awsize >> sampled.awburst >> sampled.wid >> sampled.wdata >> sampled.wstrb >> sampled.wlast;
}

// Saves DiffTest and reference-model state.
void DiffTest::save(VerilatedSerialize &out, const Ram &ram) const {
  out.write(gpr.data(), sizeof(gpr));
  out << static_cast<uint64_t>(recent.size());
  for (const Commit &commit: recent) {
    save_commit(out, commit);
  }
  out << error << nr_commit;
  cpu->save(out);

  la_tlb_state_t tlb = ref.get_tlb();
  out.write(&ref_state, sizeof(ref_state));
  out.write(&tlb, sizeof(tlb));
  cpu->save_ref(out, ref);

  std::vector<uint32_t> page_list = ram.pages();
  out << static_cast<uint64_t>(page_list.size());
  std::array<uint8_t, 4096> data{};
  for (uint32_t addr: page_list) {
    out << addr;
    ref.memcpy_from_ref(addr, data.data(), data.size());
    out.write(data.data(), data.size());
  }
}

// Restores DiffTest and reference-model state.
void DiffTest::load(VerilatedDeserialize &in) {
  in.read(gpr.data(), sizeof(gpr));
  recent.clear();
  uint64_t history = read_count(in, 16, "DiffTest history");
  for (uint64_t index = 0; index < history; index++) {
    Commit commit;
    load_commit(in, commit);
    recent.push_back(commit);
  }
  in >> error >> nr_commit;
  cpu->load(in);

  la_ref_state_t regs{};
  la_tlb_state_t tlb{};
  in.read(&regs, sizeof(regs));
  in.read(&tlb, sizeof(tlb));
  ref.set_regs(regs);
  ref_state = regs;
  cpu->load_ref(in, ref);
  ref.set_tlb(tlb);

  uint64_t count = read_count(in, 1ULL << 20U, "reference memory page");
  std::array<uint8_t, 4096> data{};
  for (uint64_t index = 0; index < count; index++) {
    uint32_t addr = 0;
    in >> addr;
    in.read(data.data(), data.size());
    ref.memcpy_to_ref(addr, data.data(), data.size());
  }
}

// Atomically saves RTL, device, and optional DiffTest state to a checkpoint.
void save_checkpoint(const std::string &file, VerilatedContext &context, Vverilator_top &top, const Axi &axi,
                     const DiffTest *diff, uint64_t cycles, uint64_t commits) {
  std::filesystem::path target(file);
  if (!target.parent_path().empty()) {
    std::filesystem::create_directories(target.parent_path());
  }
  std::filesystem::path tmp = target;
  tmp += ".tmp";

  std::error_code error;
  std::filesystem::remove(tmp, error);
  VerilatedSave out;
  out.open(tmp.string());
  if (!out.isOpen()) {
    throw std::runtime_error("cannot create checkpoint: " + tmp.string());
  }

  out << CHECKPOINT_MAGIC << CHECKPOINT_VERSION << cycles << commits << (diff != nullptr);
  out << &context << top;
  axi.save(out);
  if (diff) {
    diff->save(out, axi.ram());
  }
  out.close();

  std::filesystem::rename(tmp, target, error);
  if (error) {
    std::filesystem::remove(target, error);
    error.clear();
    std::filesystem::rename(tmp, target, error);
  }
  if (error) {
    throw std::runtime_error("cannot publish checkpoint " + file + ": " + error.message());
  }
}

// Restores the complete simulator state from a checkpoint.
void load_checkpoint(const std::string &file, VerilatedContext &context, Vverilator_top &top, Axi &axi, DiffTest *diff,
                     uint64_t &cycles, uint64_t &commits) {
  VerilatedRestore in;
  in.open(file);
  if (!in.isOpen()) {
    throw std::runtime_error("cannot open checkpoint: " + file);
  }

  uint64_t magic = 0;
  uint32_t version = 0;
  bool saved_diff = false;
  in >> magic >> version >> cycles >> commits >> saved_diff;
  if (magic != CHECKPOINT_MAGIC || version != CHECKPOINT_VERSION) {
    throw std::runtime_error("unsupported or corrupt checkpoint: " + file);
  }
  if (saved_diff != (diff != nullptr)) {
    throw std::runtime_error("checkpoint DiffTest mode does not match command line");
  }

  in >> &context >> top;
  axi.load(in);
  if (diff) {
    diff->load(in);
  }
  in.close();
}

} // namespace openla132::sim
