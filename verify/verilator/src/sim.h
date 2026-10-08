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

#pragma once

#include "difftest-ref.h"
#include "la_config.h"
#include <array>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

class Vverilator_top;
class VerilatedContext;
class VerilatedDeserialize;
class VerilatedSerialize;

namespace openla132::sim {

constexpr uint32_t DEFAULT_BOOT_PC = 0x1c000000U;
constexpr uint32_t UART_BASE = 0x1fe00000U;
constexpr uint32_t trap_instruction(uint32_t code) {
  return 0x02800000U | ((code & 0xfffU) << 10U);
}
static_assert(LA_EXIT_INSN_GOOD <= 0x7ff, "good-trap code must fit the positive addi.w immediate range");
static_assert(LA_EXIT_INSN_BAD <= 0x7ff, "bad-trap code must fit the positive addi.w immediate range");
constexpr uint32_t GOOD_TRAP = trap_instruction(LA_EXIT_INSN_GOOD);
constexpr uint32_t BAD_TRAP = trap_instruction(LA_EXIT_INSN_BAD);

struct LoadSpec {
  std::string file;
  uint32_t addr = 0;
};

struct SimArgs {
  std::string image;
  std::string ref;
  std::string ref_arch = "loongarch32s";
  std::string cpu = "la132";
  std::string wave;
  std::string checkpoint;
  std::string restore;
  uint64_t max_cycles = 100000000ULL;
  uint64_t max_commits = 0;
  uint64_t checkpoint_interval = 0;
  uint64_t ram_size = 512ULL * 1024ULL * 1024ULL;
  uint32_t reset_cycles = 32;
  uint32_t load_addr = DEFAULT_BOOT_PC;
  uint32_t boot_pc = DEFAULT_BOOT_PC;
  std::vector<LoadSpec> loads;
  bool boot_pc_set = false;
  bool diff = true;
  bool commit_log = false;
  bool quiet_uart = false;
  bool help = false;
};

SimArgs parse_args(int argc, char **argv);
std::string usage(const char *program);

struct Segment {
  uint32_t addr = 0;
  std::vector<uint8_t> data;
};

struct Image {
  uint32_t entry = DEFAULT_BOOT_PC;
  std::vector<Segment> segments;
};

Image load_image(const std::string &file, uint32_t raw_addr);

class Ram {
public:
  explicit Ram(uint64_t size);

  bool valid(uint64_t addr, size_t len = 1) const;
  uint8_t read8(uint32_t addr) const;
  uint32_t read32(uint32_t addr) const;
  void write8(uint32_t addr, uint8_t data);
  void load(uint32_t addr, const std::vector<uint8_t> &data);
  std::vector<uint32_t> pages() const;
  void save(VerilatedSerialize &stream) const;
  void load(VerilatedDeserialize &stream);

private:
  static constexpr uint32_t PAGE_BITS = 12;
  static constexpr uint32_t PAGE_SIZE = 1U << PAGE_BITS;
  using Page = std::array<uint8_t, PAGE_SIZE>;

  const Page *find_page(uint32_t addr) const;
  Page &new_page(uint32_t addr);

  uint64_t size;
  std::unordered_map<uint32_t, std::unique_ptr<Page>> page_map;
};

class Uart {
public:
  explicit Uart(bool quiet);

  uint8_t read(uint32_t offset, bool consume_rx = true);
  void write(uint32_t offset, uint8_t data);
  bool is_rx_data_read(uint32_t offset) const;
  void consume_rx_data(uint32_t offset);
  void receive(uint8_t data);
  void write_console(uint8_t data);
  const std::string &output() const;
  void save(VerilatedSerialize &stream) const;
  void load(VerilatedDeserialize &stream);

private:
  void putchar(uint8_t ch);

  bool quiet;
  uint8_t dll = 0;
  uint8_t dlm = 0;
  uint8_t ier = 0;
  uint8_t lcr = 0;
  uint8_t mcr = 0;
  uint8_t scr = 0;
  std::deque<uint8_t> rx;
  std::string tx;
};

class Axi {
public:
  Axi(uint64_t ram_size, bool quiet_uart);

  void reset();
  void load(const Image &image);
  void drive(Vverilator_top &top);
  void sample(const Vverilator_top &top);
  void tick();

  const Ram &ram() const;
  Ram &ram();
  bool device_hit(uint32_t addr) const;
  bool is_uart_rx_read(uint32_t addr) const;
  uint32_t read_device(uint32_t addr, bool consume_rx = true);
  void consume_uart_rx(uint32_t addr);
  void write_device(uint32_t addr, uint32_t data, uint8_t strb);
  void receive_uart(uint8_t data);
  void save(VerilatedSerialize &stream) const;
  void load(VerilatedDeserialize &stream);

private:
  struct Read {
    uint8_t id;
    uint32_t addr;
    uint8_t len;
    uint8_t size;
    uint8_t burst;
    uint8_t beat = 0;
    uint32_t data = 0;
    uint8_t resp = 0;
    bool ready = false;
  };

  struct Write {
    uint8_t id;
    uint32_t addr;
    uint8_t len;
    uint8_t size;
    uint8_t burst;
    uint8_t beat = 0;
    uint8_t resp = 0;
  };

  struct WData {
    uint32_t data;
    uint8_t strb;
    bool last;
  };

  struct BResp {
    uint8_t id;
    uint8_t resp;
  };

  struct Sample {
    bool ar = false;
    bool r = false;
    bool aw = false;
    bool w = false;
    bool b = false;
    uint8_t arid = 0;
    uint32_t araddr = 0;
    uint8_t arlen = 0;
    uint8_t arsize = 0;
    uint8_t arburst = 0;
    uint8_t awid = 0;
    uint32_t awaddr = 0;
    uint8_t awlen = 0;
    uint8_t awsize = 0;
    uint8_t awburst = 0;
    uint8_t wid = 0;
    uint32_t wdata = 0;
    uint8_t wstrb = 0;
    bool wlast = false;
  };

  static uint32_t next_addr(uint32_t addr, uint8_t size, uint8_t burst, uint8_t len);
  uint8_t read_beat(Read &req);
  uint8_t write_beat(const Write &req, const WData &data);
  bool read_device8(uint32_t addr, uint8_t &data, bool consume_rx = true);
  bool write_device8(uint32_t addr, uint8_t data);
  uint8_t read8(uint32_t addr, uint8_t &resp);
  void write8(uint32_t addr, uint8_t data, uint8_t &resp);
  void drain_writes();
  size_t aw_count() const;
  size_t w_count() const;

  static constexpr size_t QUEUE_SIZE = 32;

  Ram mem;
  Uart uart;
  uint32_t led_data = 0;
  std::deque<Read> read_q;
  std::array<std::deque<Write>, 16> write_q;
  std::array<std::deque<WData>, 16> wdata_q;
  std::deque<BResp> bresp_q;
  Sample sampled;
};

class Ref {
public:
  Ref(const std::string &so_file, const std::string &arch, uint64_t ram_size);
  ~Ref();

  Ref(const Ref &) = delete;
  Ref &operator=(const Ref &) = delete;

  void memcpy_to_ref(uint64_t addr, const void *data, size_t size);
  void memcpy_from_ref(uint64_t addr, void *data, size_t size) const;
  void set_regs(const la_ref_state_t &regs);
  la_ref_state_t regs() const;
  void set_csr(uint32_t index, uint64_t value, uint64_t mask = ~0ULL);
  uint64_t get_csr(uint32_t index) const;
  void set_tlb(const la_tlb_state_t &tlb);
  la_tlb_state_t get_tlb() const;
  void exec(uint64_t count);

private:
  using InitFn = void (*)();
  using InitV2Fn = void (*)(unsigned);
  using SetRamSizeFn = void (*)(size_t);
  using MemcpyFn = void (*)(uint64_t, void *, size_t, bool);
  using RegcpyFn = void (*)(void *, bool, bool);
  using CsrcpyFn = void (*)(int, uint64_t *, uint64_t, bool);
  using TlbcpyFn = void (*)(void *, bool);
  using ExecFn = void (*)(uint64_t);
  using CloseFn = void (*)();

  void *so = nullptr;
  MemcpyFn memcpy_fn = nullptr;
  RegcpyFn regcpy_fn = nullptr;
  CsrcpyFn csrcpy_fn = nullptr;
  TlbcpyFn tlbcpy_fn = nullptr;
  ExecFn exec_fn = nullptr;
  CloseFn close_fn = nullptr;
};

struct Commit {
  uint32_t pc = 0;
  uint32_t inst = 0;
  uint32_t wdata = 0;
  uint8_t wdest = 0;
  bool wen = false;
  bool cancel = false;
  bool mmio = false;
};

struct DiffState {
  uint32_t int_entry = 0;
  uint32_t crmd = 0;
  uint32_t prmd = 0;
  uint32_t ecfg = 0;
  uint32_t estat = 0;
  uint32_t era = 0;
  uint32_t badv = 0;
  uint32_t eentry = 0;
  uint32_t tval = 0;
  bool int_taken = false;
};

enum class DiffAction {
  Exec,
  Skip,
  Fail
};

class DiffMicro {
public:
  virtual ~DiffMicro() = default;

  virtual void sample(const Vverilator_top &top) = 0;
  virtual bool is_mmio(const Vverilator_top &top) const = 0;
  virtual uint32_t instruction(uint32_t pc, uint32_t fallback) const = 0;
  virtual void init(Ref &ref, uint32_t pc) = 0;
  virtual void observe(const DiffState &state) = 0;
  virtual void sync(Ref &ref, la_ref_state_t &regs) = 0;
  virtual bool fix_pc(const Commit &commit, Ref &ref, la_ref_state_t &regs) = 0;
  virtual DiffAction before_exec(const Commit &commit, const std::array<uint32_t, 32> &gpr, std::string &error) = 0;
  virtual void after_exec(const Commit &commit, const std::array<uint32_t, 32> &gpr, Ref &ref,
                          la_ref_state_t &regs) = 0;
  virtual void after_commit(Ref &ref, la_ref_state_t &regs) = 0;
  virtual void save(VerilatedSerialize &stream) const = 0;
  virtual void load(VerilatedDeserialize &stream) = 0;
  virtual void save_ref(VerilatedSerialize &stream, const Ref &ref) const = 0;
  virtual void load_ref(VerilatedDeserialize &stream, Ref &ref) = 0;
};

std::unique_ptr<DiffMicro> make_diff_micro(const std::string &cpu);

std::string check_pc(const Commit &commit, const la_ref_state_t &ref);
std::string check_gpr(const std::array<uint32_t, 32> &dut, const la_ref_state_t &ref);

class DiffTest {
public:
  DiffTest(const SimArgs &args, const Image &image, uint32_t pc);

  void sample(const Vverilator_top &top);
  bool is_mmio(const Vverilator_top &top) const;
  uint32_t instruction(uint32_t pc, uint32_t fallback) const;
  void observe(const DiffState &state);
  bool step(const Commit &commit);
  const std::string &last_error() const;
  void save(VerilatedSerialize &stream, const Ram &ram) const;
  void load(VerilatedDeserialize &stream);

private:
  std::string dump_recent() const;

  Ref ref;
  std::unique_ptr<DiffMicro> cpu;
  la_ref_state_t ref_state{};
  std::array<uint32_t, 32> gpr{};
  std::deque<Commit> recent;
  std::string error;
  uint64_t nr_commit = 0;
};

void save_checkpoint(const std::string &file, VerilatedContext &context, Vverilator_top &top, const Axi &axi,
                     const DiffTest *diff, uint64_t cycles, uint64_t commits);
void load_checkpoint(const std::string &file, VerilatedContext &context, Vverilator_top &top, Axi &axi, DiffTest *diff,
                     uint64_t &cycles, uint64_t &commits);

} // namespace openla132::sim
