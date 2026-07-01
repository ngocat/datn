## 9. Phân tích độ trễ (Latency) và hiệu năng

### 9.1 CPI (Cycles Per Instruction)

| Loại lệnh | Ví dụ | Số state | Số clock cycle | Giải thích |
|-----------|-------|----------|---------------|-------------|
| ALU R-type | ADD, SUB, AND | FETCH+EXECUTE | ~3-4 | Fetch 2 cycle (SRAM delay) + Execute 1 cycle |
| ALU I-type | ADDI, ORI | FETCH+EXECUTE | ~3-4 | Tương tự R-type |
| Branch (taken) | BEQ (nhảy) | FETCH+EXECUTE | ~3-4 | Tương tự, PC thay đổi |
| Branch (not taken) | BEQ (không nhảy) | FETCH+EXECUTE | ~3-4 | Tương tự |
| JAL/JALR | JAL label | FETCH+EXECUTE | ~3-4 | Ghi PC+4 + nhảy |
| LUI/AUIPC | LUI x1, 0x12 | FETCH+EXECUTE | ~3-4 | Ghi immediate/PC+imm |
| Load (SRAM) | LW x1, 0(x2) | FETCH+EXECUTE+MEMREQ | ~5-6 | Fetch 2c + Execute 1c + MemReq 2c |
| Store (SRAM) | SW x1, 0(x2) | FETCH+EXECUTE+MEMREQ | ~5-6 | Tương tự Load |
| Load (I/O) | LW từ UART | FETCH+EXECUTE+MEMREQ | ~4-10+ | Phụ thuộc peripheral ready time |

### 9.2 SRAM Latency Detail

Gowin BRAM (Block RAM) yêu cầu **1 clock cycle** để đọc:
```
Cycle 1: CPU đặt mem_valid=1, mem_addr=X
         → sram_sel lên 1, Gowin_SP nhận địa chỉ
Cycle 2: sram_ready lên 1, dữ liệu có trên sram_data_o
         → mem_ready = mem_valid & sram_ready = 1
         → CPU đọc mem_rdata
```

Nên mỗi bus transaction (fetch hoặc load/store) tốn **2 clock cycles** cho SRAM.

### 9.3 Tổng kết hiệu năng

**Average CPI ≈ 3.5 - 4.5 cycles** (giả sử ~20% lệnh là load/store)

Công thức: `CPI_avg = 0.8 × 3.5 + 0.2 × 5.5 ≈ 3.9`

**So sánh:**
- Lý tưởng (single-cycle): CPI = 1
- PicoRV32: CPI ≈ 4-6 (multi-cycle, phức tạp hơn)
- Core này: CPI ≈ 3.5-4.5

### 9.4 Tần số hoạt động (Fmax)

Tang Nano 9K crystal: **27 MHz** (không có PLL trong project này → chạy 27 MHz)

**Throughput ước tính:**
- `27 MHz / 4 CPI ≈ 6.75 MIPS` (triệu lệnh/giây)
- PicoRV32 trên cùng board: `27 MHz / 5 CPI ≈ 5.4 MIPS`

---

## 10. So sánh với PicoRV32

| Tiêu chí | PicoRV32 | rv32i_bus (core tự viết) |
|----------|----------|-------------------------|
| **Kiến trúc** | Multi-cycle phức tạp | Multi-cycle đơn giản (3 state) |
| **Dòng code** | ~3000 dòng Verilog | ~800 dòng (tổng tất cả module) |
| **RV32I** | Đầy đủ | Đầy đủ (37 lệnh) |
| **RV32M** (Mul/Div) | Tùy chọn | Không |
| **Compressed (RV32C)** | Tùy chọn | Không |
| **IRQ** | Có (custom, không theo RISC-V spec) | Không |
| **trap** | Có (illegal instruction, misalign) | Chưa implement |
| **Barrel Shifter** | Tùy chọn | Không (shift bình thường) |
| **CPI** | ~4-6 | ~3.5-4.5 |
| **Fmax** | Cao (đã optimize kỹ) | Trung bình |
| **Dễ hiểu** | Khó (code phức tạp) | Dễ (chia module rõ) |
| **Tài nguyên FPGA** | Nhiều hơn (nhiều tính năng) | Ít hơn (đơn giản) |

---

## 11. Ưu điểm và nhược điểm

### 11.1 Ưu điểm

1. **Code sạch, dễ hiểu:** Chia module rõ ràng (ALU, Decoder, RegFile...), mỗi module có 1 chức năng
2. **Đúng chuẩn RV32I:** Hỗ trợ đầy đủ 37 lệnh integer base
3. **Byte/Halfword addressing:** Hỗ trợ LB/LBU/LH/LHU/SB/SH — nhiều core đơn giản bỏ qua
4. **Bus compatible:** Sau khi thêm wrapper, tương thích hoàn toàn với SoC có sẵn
5. **Nhỏ gọn:** ~800 dòng code, tiết kiệm tài nguyên FPGA
6. **CPI tốt:** 3.5-4.5 cycles — ngang hoặc tốt hơn PicoRV32
7. **ALU decoder logic chính xác:** Phân biệt đúng SUB/SRA giữa R-type và I-type

### 11.2 Nhược điểm

1. **Không có IRQ (Interrupt):** Không thể xử lý ngắt — phần mềm phải polling
2. **Không có trap:** Lệnh bất hợp lệ hoặc truy cập sai → hành vi không xác định
3. **Không có CSR:** Không hỗ trợ System registers (mcycle, mstatus...)
4. **Không có phần mở rộng M:** Không có MUL/DIV — phải dùng thuật toán software
5. **Không có RV32C:** Không hỗ trợ compressed instructions → code size lớn hơn
6. **Không có pipeline:** Mỗi lệnh đi qua tuần tự, không overlap
7. **Không có FENCE/ECALL/EBREAK:** Thiếu một số lệnh system

### 12.1 Dễ (Có thể làm ngay)
- [ ] Thêm trap cho illegal instruction
- [ ] Thêm timeout cho bus hang (watchdog)
- [ ] Sửa `default` trong SignExtend.v
- [ ] Thêm FENCE (NOP implementation)
- [ ] Thêm ECALL/EBREAK (trap implementation)

### 12.2 Trung bình
- [ ] Thêm pipeline 2-stage (Fetch | Execute+Memory) → CPI ≈ 2
- [ ] Thêm CSR registers (mcycle, minstret cho performance counter)
- [ ] Thêm phần mở rộng M (MUL/DIV bằng sequential multiplier)
- [ ] Thêm IRQ support cơ bản

### 12.3 Nâng cao
- [ ] Pipeline 5-stage (IF | ID | EX | MEM | WB) → CPI ≈ 1
- [ ] Hazard detection + forwarding
- [ ] Branch prediction
- [ ] Instruction cache / Data cache
- [ ] Compressed instruction (RV32C) support
- [ ] Memory Management Unit (MMU)


## 14. Danh sách file và chức năng

### 14.1 Folder `mycreateriscv/` — CPU Core tự thiết kế

| File | Module | Chức năng |
|------|--------|-----------|
| `rv32i_bus.v` | rv32i_bus | **Wrapper chính** — state machine 3 trạng thái, bus interface |
| `alu.v` | ALU | Bộ tính toán 10 phép toán |
| `ALU_decoder.v` | ALU_decoder | Giải mã phép toán ALU từ funct3/funct7 |
| `Main_decoder.v` | main_decoder | Giải mã tín hiệu điều khiển từ opcode |
| `control_top.v` | control | Kết hợp Main + ALU decoder + Branch logic |
| `Regfile.v` | regfile | 32 thanh ghi 32-bit (2R1W) |
| `SignExtend.v` | signextend | Mở rộng immediate 5 loại format |
| `load_store_decoder.v` | load_store_decoder | Tính byte enable + shift data cho store |
| `Reader.v` | reader | Đọc + shift + sign extend cho load |
| `pc.v` | PC | Thanh ghi Program Counter (không dùng trong rv32i_bus) |
| `InstructionMem.v` | instr_mem | Instruction memory (không dùng trong rv32i_bus) |
| `core_rv32i.v` | top | Core single-cycle gốc (không dùng, giữ làm tham khảo) |

### 14.2 Folder `src/` — SoC, Peripheral, và Tool chain

| File | Module | Chức năng |
|------|--------|-----------|
| `top.v` | top | **Top-level SoC** — kết nối CPU + peripherals |
| `sram.v` | sram | 8KB SRAM từ 4 Gowin_SP BRAM |
| `tang_nano_9k_leds.v` | tang_leds | LED controller 6-bit |
| `simpleuart.v` | simpleuart | UART transceiver |
| `uart_wrap.v` | uart_wrap | UART bus wrapper (div + dat registers) |
| `countdown_timer.v` | countdown_timer | 32-bit countdown timer |
| `i2c_gpio.v` | i2c_gpio | I2C GPIO bit-bang |
| `reset.v` | reset_control | Reset sequencer (64-cycle debounce) |
| `mem_init.v` | (include) | Nội dung SRAM khởi tạo (firmware) |
| `picorv32.v` | picorv32 | PicoRV32 core gốc (**đã thay bằng rv32i_bus**) |
| `picorv32.cst` | — | Constraint file (pin mapping) |
| `picorv32.sdc` | — | Timing constraint |

### 14.3 Folder `c_code/` — Firmware C

| File | Chức năng |
|------|-----------|
| `main.c` | Chương trình chính — đọc AHT20, hiển thị OLED |
| `startup.s` | Startup assembly — set stack pointer, call main |
| `link_cmd.ld` | Linker script — memory layout |
| `Makefile` | Build system |
| `leds.c/h` | Driver LED |
| `uart.c/h` | Driver UART |
| `i2c.c/h` | Driver I2C |
| `ssd1306.c/h` | Driver OLED SSD1306 |
| `aht20.c/h` | Driver cảm biến nhiệt độ/độ ẩm |
| `countdown_timer.c/h` | Driver timer |
| `conv_to_init.c` | Tool chuyển firmware binary → mem_init.v |




*Báo cáo được tạo ngày 06/04/2026*
*Core tự thiết kế bởi tác giả, integrated bởi AI assistant*
*Target platform: Sipeed Tang Nano 9K (Gowin GW1NR-9C)*
