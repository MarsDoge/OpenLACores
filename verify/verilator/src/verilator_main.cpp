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
#include "verilated_vcd_c.h"
#include <algorithm>
#include <atomic>
#include <cerrno>
#include <csignal>
#include <filesystem>
#include <fcntl.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <limits>
#include <memory>
#include <stdexcept>
#include <system_error>
#include <termios.h>
#include <unistd.h>

namespace {

std::atomic<bool> stop{false};

// Requests a safe simulator shutdown when a termination signal arrives.
void signal_handler(int) {
  stop.store(true);
}

// Reads an instruction from RAM using LoongArch direct-address mapping.
uint32_t read_inst(const openla132::sim::Ram &ram, uint32_t pc) {
  uint32_t addr = (pc & 0x80000000U) ? pc & 0x1fffffffU : pc;
  return ram.read32(addr);
}

#ifdef OPEN132_VERILATOR_SRAM
class SramInitFiles {
public:
  // Creates independent instruction- and data-SRAM initialization files.
  explicit SramInitFiles(const openla132::sim::Image &image) {
    constexpr uint32_t isram_base = 0x1c000000U;
    constexpr uint32_t dsram_base = 0x15000000U;
    constexpr size_t size = 16U * 1024U * 1024U;
    std::vector<uint8_t> isram(size, 0);
    std::vector<uint8_t> dsram(size, 0);

    for (const openla132::sim::Segment &segment: image.segments) {
      if (segment.data.empty()) {
        continue;
      }
      if (copy_segment(segment, isram_base, isram) || copy_segment(segment, dsram_base, dsram)) {
        continue;
      }
      throw std::runtime_error(
          "SRAM mode maps ELF physical segments only into 0x1c000000..0x1cffffff or 0x15000000..0x15ffffff");
    }

    std::string tag = std::to_string(static_cast<unsigned long>(getpid()));
    paths[0] = std::filesystem::temp_directory_path() / ("openla132-isram-" + tag + ".hex");
    paths[1] = std::filesystem::temp_directory_path() / ("openla132-dsram-" + tag + ".hex");
    write_file(paths[0], isram);
    write_file(paths[1], dsram);
    plusargs[0] = "+OPEN132_ISRAM_INIT=" + paths[0].string();
    plusargs[1] = "+OPEN132_DSRAM_INIT=" + paths[1].string();
  }

  // Removes the temporary SRAM initialization files.
  ~SramInitFiles() {
    for (const std::filesystem::path &path: paths) {
      std::error_code error;
      std::filesystem::remove(path, error);
    }
  }

  // Returns the SRAM initialization plusargs for Verilator.
  const std::array<std::string, 2> &arguments() const {
    return plusargs;
  }

private:
  static bool copy_segment(const openla132::sim::Segment &segment, uint32_t base, std::vector<uint8_t> &bytes) {
    uint64_t begin = segment.addr;
    uint64_t end = begin + segment.data.size();
    if (begin < base || end > static_cast<uint64_t>(base) + bytes.size()) {
      return false;
    }
    std::copy(segment.data.begin(), segment.data.end(), bytes.begin() + (segment.addr - base));
    return true;
  }

  static void write_file(const std::filesystem::path &path, const std::vector<uint8_t> &bytes) {
    std::ofstream out(path, std::ios::trunc);
    if (!out) {
      throw std::runtime_error("cannot create SRAM initialization image: " + path.string());
    }
    out << std::hex << std::setfill('0');
    for (size_t offset = 0; offset < bytes.size(); offset += 4) {
      uint32_t word = static_cast<uint32_t>(bytes[offset])
                      | (static_cast<uint32_t>(bytes[offset + 1]) << 8U)
                      | (static_cast<uint32_t>(bytes[offset + 2]) << 16U)
                      | (static_cast<uint32_t>(bytes[offset + 3]) << 24U);
      out << std::setw(8) << word << '\n';
    }
    out.close();
    if (!out) {
      std::error_code error;
      std::filesystem::remove(path, error);
      throw std::runtime_error("cannot write SRAM initialization image: " + path.string());
    }
  }

  std::array<std::filesystem::path, 2> paths;
  std::array<std::string, 2> plusargs;
};
#endif

class HostUartInput {
public:
  HostUartInput() {
    terminal_input = isatty(STDIN_FILENO);
    original_flags = fcntl(STDIN_FILENO, F_GETFL);
    if (original_flags >= 0 && fcntl(STDIN_FILENO, F_SETFL, original_flags | O_NONBLOCK) == 0) {
      restore_flags = true;
    }

    if (terminal_input && tcgetattr(STDIN_FILENO, &original_termios) == 0) {
      termios raw = original_termios;
      raw.c_lflag &= static_cast<tcflag_t>(~(ICANON | ECHO | ECHONL));
      raw.c_cc[VMIN] = 0;
      raw.c_cc[VTIME] = 0;
      if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0) {
        restore_termios = true;
      }
    }
  }

  ~HostUartInput() {
    if (restore_termios) {
      tcsetattr(STDIN_FILENO, TCSANOW, &original_termios);
    }
    if (restore_flags) {
      fcntl(STDIN_FILENO, F_SETFL, original_flags);
    }
  }

  void poll(openla132::sim::Axi &devices, uint64_t cycle) {
    if (!eof && cycle >= next_poll) {
      read_input(devices);
      next_poll = cycle > UINT64_MAX - POLL_INTERVAL ? UINT64_MAX : cycle + POLL_INTERVAL;
    }
  }

private:
  void read_input(openla132::sim::Axi &devices) {
    std::array<uint8_t, 256> buffer{};
    size_t received = 0;
    while (received < MAX_BATCH) {
      size_t space = std::min(buffer.size(), MAX_BATCH - received);
      ssize_t count = ::read(STDIN_FILENO, buffer.data(), space);
      if (count > 0) {
        for (ssize_t index = 0; index < count; index++) {
          devices.receive_uart(buffer[static_cast<size_t>(index)]);
        }
        received += static_cast<size_t>(count);
        continue;
      }
      if (count == 0) {
        // A noncanonical terminal with VMIN=0 reports "no input" as a
        // zero-length read.  Only a pipe/file uses zero to signal EOF here.
        eof = !terminal_input;
      } else if (errno == EINTR) {
        continue;
      } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
        eof = true;
      }
      break;
    }
  }

  static constexpr uint64_t POLL_INTERVAL = 1024;
  static constexpr size_t MAX_BATCH = 4096;

  termios original_termios{};
  int original_flags = -1;
  uint64_t next_poll = 0;
  bool restore_flags = false;
  bool restore_termios = false;
  bool terminal_input = false;
  bool eof = false;
};

#ifdef OPEN132_VERILATOR_SRAM
class SramDeviceBridge {
public:
  explicit SramDeviceBridge(openla132::sim::Axi &devices) : devices(devices) {}

  void drive(Vverilator_top &top) {
    if (!top.resetn) {
      reset();
      top.sram_device_hit = 0;
      top.sram_device_ack = 0;
      top.sram_device_rrdy = 0;
      top.sram_device_rdata = 0;
      top.sram_device_resp = 0;
      return;
    }

    bool hit = top.sram_device_valid && devices.device_hit(top.sram_device_addr);
    top.sram_device_hit = hit;
    top.sram_device_ack = hit;
    top.sram_device_rrdy = response_valid;
    top.sram_device_rdata = response_data;
    top.sram_device_resp = 0;
  }

  void sample(const Vverilator_top &top) {
    response_valid = false;
    write_pending = false;
    if (!top.sram_device_valid || !top.sram_device_hit || !top.sram_device_ack) {
      consume_pending_uart_rx();
      return;
    }

    request.write = top.sram_device_write;
    request.strb = top.sram_device_strb;
    request.addr = top.sram_device_addr;
    request.data = top.sram_device_wdata;
    bool uart_rx_read = !request.write && devices.is_uart_rx_read(request.addr);
    bool repeated_uart_rx_read = uart_rx_pending && uart_rx_read && request.addr == pending_uart_rx_addr;
    if (uart_rx_pending && !repeated_uart_rx_read) {
      consume_pending_uart_rx();
    }

    if (request.write) {
      write_pending = true;
    } else if (uart_rx_read) {
      response_data = devices.read_device(request.addr, repeated_uart_rx_read);
      response_valid = true;
      if (repeated_uart_rx_read) {
        uart_rx_pending = false;
      } else {
        uart_rx_pending = true;
        pending_uart_rx_addr = request.addr;
      }
    } else {
      response_data = devices.read_device(request.addr);
      response_valid = true;
    }
  }

  void advance() {
    if (write_pending) {
      devices.write_device(request.addr, request.data, request.strb);
    }
    write_pending = false;
    response_valid = false;
  }

private:
  struct Request {
    bool write = false;
    uint8_t strb = 0;
    uint32_t addr = 0;
    uint32_t data = 0;
  };

  void consume_pending_uart_rx() {
    if (uart_rx_pending) {
      devices.consume_uart_rx(pending_uart_rx_addr);
      uart_rx_pending = false;
    }
  }

  void reset() {
    request = {};
    uart_rx_pending = false;
    pending_uart_rx_addr = 0;
    write_pending = false;
    response_valid = false;
    response_data = 0;
  }

  openla132::sim::Axi &devices;
  Request request;
  uint32_t response_data = 0;
  uint32_t pending_uart_rx_addr = 0;
  bool uart_rx_pending = false;
  bool write_pending = false;
  bool response_valid = false;
};
#endif

class Wave {
public:
  // Creates a VCD waveform writer when tracing is requested.
  Wave(VerilatedContext &context, Vverilator_top &top, const std::string &file) {
    if (file.empty()) {
      return;
    }
    context.traceEverOn(true);
    trace = std::make_unique<VerilatedVcdC>();
    top.trace(trace.get(), 8);
    trace->open(file.c_str());
    if (!trace->isOpen()) {
      throw std::runtime_error("cannot open waveform file: " + file);
    }
  }

  // Closes the VCD waveform writer.
  ~Wave() {
    if (trace) {
      trace->close();
    }
  }

  // Dumps waveform state at the specified simulation time.
  void dump(uint64_t time) {
    if (trace) {
      trace->dump(time);
    }
  }

private:
  std::unique_ptr<VerilatedVcdC> trace;
};

} // namespace

// Runs the Verilator model with AXI devices and optional instruction-level difftest.
int main(int argc, char **argv) {
  using namespace openla132::sim;

  try {
    SimArgs args = parse_args(argc, argv);
    if (args.help) {
      std::cout << usage(argv[0]);
      return 0;
    }

    Image image;
    if (!args.image.empty()) {
      image = load_image(args.image, args.load_addr);
    }
    for (const LoadSpec &spec: args.loads) {
      Image extra = load_image(spec.file, spec.addr);
      image.segments.insert(image.segments.end(), std::make_move_iterator(extra.segments.begin()),
                            std::make_move_iterator(extra.segments.end()));
    }
    uint32_t boot_pc = args.boot_pc_set ? args.boot_pc : image.entry;
    bool restoring = !args.restore.empty();

    VerilatedContext context;
    context.commandArgs(argc, argv);
#ifdef OPEN132_VERILATOR_SRAM
    std::unique_ptr<SramInitFiles> sram_init;
    if (!restoring) {
      sram_init = std::make_unique<SramInitFiles>(image);
      std::array<const char *, 2> sram_args = {
          sram_init->arguments()[0].c_str(),
          sram_init->arguments()[1].c_str(),
      };
      context.commandArgsAdd(static_cast<int>(sram_args.size()), sram_args.data());
    }
#endif
    Vverilator_top top(&context);
    top.sram_device_hit = 0;
    top.sram_device_ack = 0;
    top.sram_device_rrdy = 0;
    top.sram_device_rdata = 0;
    top.sram_device_resp = 0;
    Axi axi(args.ram_size, args.quiet_uart);
    axi.load(image);
    axi.reset();
    HostUartInput host_uart_input;
#ifdef OPEN132_VERILATOR_SRAM
    SramDeviceBridge sram_devices(axi);
#endif

    std::unique_ptr<DiffTest> diff;
    if (args.diff) {
      diff = std::make_unique<DiffTest>(args, image, boot_pc);
    }

    uint64_t cycles = 0;
    uint64_t commits = 0;
    if (restoring) {
      load_checkpoint(args.restore, context, top, axi, diff.get(), cycles, commits);
      std::cerr << "[checkpoint] restored " << args.restore << " cycle=" << cycles << " commits=" << commits << '\n';
    } else {
      top.clk = 0;
      top.resetn = 0;
      top.boot_pc = boot_pc;
      top.ext_int = 0;
    }

    Wave wave(context, top, args.wave);
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    int result = 2;
    bool done = false;
    uint64_t last_checkpoint = UINT64_MAX;
    uint64_t cycle_limit = args.max_cycles > UINT64_MAX - cycles ? UINT64_MAX : cycles + args.max_cycles;
    uint64_t commit_limit = !args.max_commits                         ? 0
                            : args.max_commits > UINT64_MAX - commits ? UINT64_MAX
                                                                      : commits + args.max_commits;
    uint64_t next_checkpoint = UINT64_MAX;
    if (!args.checkpoint.empty()) {
      uint64_t slot = cycles / args.checkpoint_interval;
      next_checkpoint =
          slot >= UINT64_MAX / args.checkpoint_interval ? UINT64_MAX : (slot + 1U) * args.checkpoint_interval;
    }

    std::cerr << "[sim] image=" << (args.image.empty() ? "<checkpoint>" : args.image) << " entry=0x" << std::hex
              << std::setw(8) << std::setfill('0') << boot_pc << " ram=0x" << args.ram_size
              << " difftest=" << (args.diff ? "on" : "off")
#ifdef OPEN132_VERILATOR_SRAM
              << " memory=sram"
#else
              << " memory=axi"
#endif
              << std::dec << '\n';

    while (cycles < cycle_limit && !done && !context.gotFinish()) {
      top.resetn = cycles >= args.reset_cycles;

      host_uart_input.poll(axi, cycles);
#ifdef OPEN132_VERILATOR_SRAM
      sram_devices.drive(top);
#endif
      top.clk = 0;
      axi.drive(top);
      top.eval();
#ifdef OPEN132_VERILATOR_SRAM
      sram_devices.sample(top);
      sram_devices.drive(top);
      top.eval();
#endif
      if (diff) {
        diff->sample(top);
      }
      bool commit_mmio = diff && diff->is_mmio(top);
      axi.sample(top);
      wave.dump(context.time());
      context.timeInc(1);

      top.clk = 1;
      top.eval();
      wave.dump(context.time());
      context.timeInc(1);
      axi.tick();
#ifdef OPEN132_VERILATOR_SRAM
      sram_devices.advance();
      // A request can become visible immediately after the rising edge.  Settle
      // the address decode during the same high phase so it cannot briefly be
      // accepted by the RTL SRAM before the C++ device bridge claims it.
      sram_devices.drive(top);
      top.eval();
#endif

      if (diff) {
        DiffState state;
        state.int_taken = top.interrupt_taken;
        state.int_entry = top.interrupt_entry;
        state.crmd = top.csr_crmd;
        state.prmd = top.csr_prmd;
        state.ecfg = top.csr_ecfg;
        state.estat = top.csr_estat;
        state.era = top.csr_era;
        state.badv = top.csr_badv;
        state.eentry = top.csr_eentry;
        state.tval = top.csr_tval;
        diff->observe(state);
      }

      if (top.resetn && top.commit_valid) {
        Commit commit;
        commit.pc = top.commit_pc;
        uint32_t fallback = read_inst(axi.ram(), commit.pc);
        commit.inst = diff ? diff->instruction(commit.pc, fallback) : fallback;
        commit.wen = top.commit_wen;
        commit.wdest = top.commit_wdest;
        commit.wdata = top.commit_wdata;
        commit.cancel = top.commit_cancel;
        commit.mmio = commit_mmio;
        commits++;

        if (args.commit_log) {
          std::cerr << "[commit " << commits << "] pc=0x" << std::hex << std::setw(8) << std::setfill('0') << commit.pc
                    << " inst=0x" << std::setw(8) << commit.inst;
          if (commit.wen) {
            std::cerr << " r" << std::dec << static_cast<unsigned>(commit.wdest) << "=0x" << std::hex << std::setw(8)
                      << commit.wdata;
          }
          if (commit.cancel) {
            std::cerr << " cancel";
          }
          if (commit.mmio) {
            std::cerr << " mmio";
          }
          std::cerr << std::dec << '\n';
        }

        if (diff && !diff->step(commit)) {
          std::cerr << "\n[diff] FAILED at cycle " << cycles << ":\n" << diff->last_error() << '\n';
          result = 1;
          done = true;
        } else if (commit.inst == GOOD_TRAP) {
          std::cerr << "\n[sim] GOOD TRAP at pc=0x" << std::hex << commit.pc << std::dec << '\n';
          result = 0;
          done = true;
        } else if (commit.inst == BAD_TRAP) {
          std::cerr << "\n[sim] BAD TRAP at pc=0x" << std::hex << commit.pc << std::dec << '\n';
          result = 1;
          done = true;
        } else if (commit_limit && commits >= commit_limit) {
          std::cerr << "\n[sim] commit limit reached\n";
          result = 0;
          done = true;
        }
      }

      cycles++;
      if (!done && cycles >= next_checkpoint) {
        save_checkpoint(args.checkpoint, context, top, axi, diff.get(), cycles, commits);
        last_checkpoint = cycles;
        std::cerr << "[checkpoint] saved " << args.checkpoint << " cycle=" << cycles << " commits=" << commits << '\n';
        next_checkpoint =
            args.checkpoint_interval > UINT64_MAX - cycles ? UINT64_MAX : cycles + args.checkpoint_interval;
      }
      if (stop.load()) {
        std::cerr << "\n[sim] interrupted\n";
        result = 130;
        done = true;
      }
    }

    if (!done && context.gotFinish()) {
      result = 0;
      std::cerr << "\n[sim] RTL requested finish\n";
    } else if (!done) {
      std::cerr << "\n[sim] cycle timeout\n";
    }

    if (!args.checkpoint.empty() && result != 1 && last_checkpoint != cycles) {
      save_checkpoint(args.checkpoint, context, top, axi, diff.get(), cycles, commits);
      std::cerr << "[checkpoint] saved " << args.checkpoint << " cycle=" << cycles << " commits=" << commits << '\n';
    }

    top.final();
    double ipc = cycles ? static_cast<double>(commits) / cycles : 0.0;
    std::cerr << "[sim] cycles=" << cycles << " commits=" << commits << '\n';
#ifdef OPEN132_VERILATOR_SRAM
    std::cerr << "[sim] inst_sram accesses=" << top.inst_sram_accesses
              << " data_sram accesses=" << top.data_sram_accesses << " axi accesses=0\n";
#endif
    return result;
  } catch (const std::exception &error) {
    std::cerr << "error: " << error.what() << "\n\n" << usage(argv[0]);
    return 1;
  }
}
