# BÁO CÁO CHI TIẾT: Thiết kế CPU RISC-V 32-bit (RV32I) tự viết bằng Verilog
# Tích hợp vào SoC Tang Nano 9K thay thế PicoRV32

---

## MỤC LỤC

1. [Tổng quan dự án](#1-tổng-quan-dự-án)
2. [Kiến thức nền tảng RISC-V](#2-kiến-thức-nền-tảng-risc-v)
3. [Kiến trúc CPU ban đầu (Single-Cycle)](#3-kiến-trúc-cpu-ban-đầu-single-cycle)
4. [Phân tích từng module chi tiết](#4-phân-tích-từng-module-chi-tiết)
5. [Các bug đã phát hiện và cách sửa](#5-các-bug-đã-phát-hiện-và-cách-sửa)
6. [Kiến trúc CPU mới (Multi-Cycle Bus Wrapper)](#6-kiến-trúc-cpu-mới-multi-cycle-bus-wrapper)
7. [Hệ thống SoC Tang Nano 9K](#7-hệ-thống-soc-tang-nano-9k)
8. [Memory Map và Bus Protocol](#8-memory-map-và-bus-protocol)
9. [Phân tích độ trễ (Latency) và hiệu năng](#9-phân-tích-độ-trễ-latency-và-hiệu-năng)
10. [So sánh với PicoRV32](#10-so-sánh-với-picorv32)
11. [Ưu điểm và nhược điểm](#11-ưu-điểm-và-nhược-điểm)
12. [Hướng phát triển](#12-hướng-phát-triển)
13. [Tổng kết kiến thức Verilog đã sử dụng](#13-tổng-kết-kiến-thức-verilog-đã-sử-dụng)
14. [Danh sách file và chức năng](#14-danh-sách-file-và-chức-năng)

---

## 1. Tổng quan dự án

### 1.1 Mục tiêu
Tự thiết kế một CPU RISC-V 32-bit kiến trúc RV32I (Integer base instruction set) bằng Verilog, sau đó tích hợp vào hệ thống SoC (System on Chip) trên board FPGA **Sipeed Tang Nano 9K** (chip Gowin GW1NR-9C) để thay thế core PicoRV32 có sẵn.

### 1.2 Tổng quan hệ thống

```
┌─────────────────────────────────────────────────────────┐
│                    Tang Nano 9K SoC                     │
│                                                         │
│  ┌──────────────┐    mem_valid/mem_ready bus             │
│  │  rv32i_bus   │◄──────────────────────────────────┐   │
│  │  (CPU core)  │────────────────────────────────┐  │   │
│  └──────────────┘                                │  │   │
│         │                                        │  │   │
│  ┌──────▼───────────────────────────────────┐    │  │   │
│  │          Address Decoder                 │    │  │   │
│  │  0x00000000-0x00001FFF → SRAM (8KB)      │    │  │   │
│  │  0x80000000            → LEDs            │    │  │   │
│  │  0x80000008-0x8000000F → UART            │    │  │   │
│  │  0x80000010            → Countdown Timer │    │  │   │
│  │  0x80000020            → I2C GPIO        │    │  │   │
│  └──────────────────────────────────────────┘    │  │   │
│         │                                        │  │   │
│  ┌──────▼──────┐ ┌────┐ ┌────┐ ┌─────┐ ┌─────┐ │  │   │
│  │   SRAM      │ │LED │ │UART│ │Timer│ │ I2C │ │  │   │
│  │   8KB       │ │    │ │    │ │     │ │GPIO │ │  │   │
│  │ (4xGowin_SP)│ │    │ │    │ │     │ │     │ │  │   │
│  └─────────────┘ └────┘ └────┘ └─────┘ └─────┘ │  │   │
│                                                  │  │   │
│  mem_rdata ◄─────────────────────────────────────┘  │   │
│  mem_ready ◄────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Phần mềm chạy trên CPU
Chương trình C (`main.c`) đọc cảm biến nhiệt độ/độ ẩm AHT20 qua I2C, hiển thị lên OLED SSD1306, điều khiển LED, và giao tiếp UART. Tất cả đều chạy trên CPU tự thiết kế.

---

## 2. Kiến thức nền tảng RISC-V

### 2.1 RISC-V là gì?
RISC-V là kiến trúc tập lệnh (ISA - Instruction Set Architecture) mã nguồn mở, được thiết kế tại UC Berkeley. Khác với x86 (Intel) hay ARM, RISC-V hoàn toàn miễn phí sử dụng.

### 2.2 RV32I - Bộ lệnh cơ bản 32-bit
RV32I là bộ lệnh cơ bản nhất của RISC-V, bao gồm:
- **32 thanh ghi** tổng quát (x0-x31), mỗi thanh ghi 32-bit
- **x0** luôn bằng 0 (hardwired zero)
- **PC** (Program Counter) - thanh ghi đặc biệt trỏ đến lệnh hiện tại
- **Tất cả lệnh** đều 32-bit (4 bytes)

### 2.3 Các loại lệnh RV32I

#### Bảng 6 định dạng lệnh (Instruction Formats):

```
R-type: |  funct7  | rs2 | rs1 | funct3 | rd  | opcode |  ← Lệnh thanh ghi (add, sub, and, or...)
        | 31    25 |24 20|19 15| 14  12 |11  7| 6    0 |

I-type: |     imm[11:0]   | rs1 | funct3 | rd  | opcode |  ← Lệnh dùng hằng số (addi, lw, jalr...)
        | 31            20|19 15| 14  12 |11  7| 6    0 |

S-type: | imm[11:5] | rs2 | rs1 | funct3 |imm[4:0]| opcode |  ← Lệnh store (sw, sh, sb)
        | 31     25 |24 20|19 15| 14  12 | 11   7 | 6    0 |

B-type: |imm[12|10:5]| rs2 | rs1 | funct3 |imm[4:1|11]| opcode |  ← Lệnh rẽ nhánh (beq, bne, blt...)
        | 31      25 |24 20|19 15| 14  12 | 11      7 | 6    0 |

U-type: |          imm[31:12]           | rd  | opcode |  ← Lệnh U (lui, auipc)
        | 31                         12 |11  7| 6    0 |

J-type: |    imm[20|10:1|11|19:12]      | rd  | opcode |  ← Lệnh nhảy (jal)
        | 31                         12 |11  7| 6    0 |
```

#### Bảng đầy đủ tập lệnh RV32I hỗ trợ:

| Nhóm | Lệnh | Opcode | Mô tả | Ví dụ |
|------|-------|--------|--------|-------|
| **Toán học R** | ADD | 0110011 | rd = rs1 + rs2 | `add x1, x2, x3` |
| | SUB | 0110011 | rd = rs1 - rs2 | `sub x1, x2, x3` |
| | AND | 0110011 | rd = rs1 & rs2 | `and x1, x2, x3` |
| | OR | 0110011 | rd = rs1 \| rs2 | `or x1, x2, x3` |
| | XOR | 0110011 | rd = rs1 ^ rs2 | `xor x1, x2, x3` |
| | SLT | 0110011 | rd = (rs1 < rs2) ? 1 : 0 (signed) | `slt x1, x2, x3` |
| | SLTU | 0110011 | rd = (rs1 < rs2) ? 1 : 0 (unsigned) | `sltu x1, x2, x3` |
| | SLL | 0110011 | rd = rs1 << rs2[4:0] | `sll x1, x2, x3` |
| | SRL | 0110011 | rd = rs1 >> rs2[4:0] (logic) | `srl x1, x2, x3` |
| | SRA | 0110011 | rd = rs1 >>> rs2[4:0] (arithmetic) | `sra x1, x2, x3` |
| **Toán học I** | ADDI | 0010011 | rd = rs1 + imm | `addi x1, x2, 10` |
| | ANDI | 0010011 | rd = rs1 & imm | `andi x1, x2, 0xFF` |
| | ORI | 0010011 | rd = rs1 \| imm | `ori x1, x2, 0xFF` |
| | XORI | 0010011 | rd = rs1 ^ imm | `xori x1, x2, 0xFF` |
| | SLTI | 0010011 | rd = (rs1 < imm) ? 1 : 0 | `slti x1, x2, 10` |
| | SLTIU | 0010011 | rd = (rs1 < imm) ? 1 : 0 (unsigned) | `sltiu x1, x2, 10` |
| | SLLI | 0010011 | rd = rs1 << shamt | `slli x1, x2, 4` |
| | SRLI | 0010011 | rd = rs1 >> shamt (logic) | `srli x1, x2, 4` |
| | SRAI | 0010011 | rd = rs1 >>> shamt (arithmetic) | `srai x1, x2, 4` |
| **Load** | LW | 0000011 | rd = mem[rs1+imm] (32-bit) | `lw x1, 0(x2)` |
| | LH | 0000011 | rd = sign_ext(mem[rs1+imm]) (16-bit) | `lh x1, 0(x2)` |
| | LHU | 0000011 | rd = zero_ext(mem[rs1+imm]) (16-bit) | `lhu x1, 0(x2)` |
| | LB | 0000011 | rd = sign_ext(mem[rs1+imm]) (8-bit) | `lb x1, 0(x2)` |
| | LBU | 0000011 | rd = zero_ext(mem[rs1+imm]) (8-bit) | `lbu x1, 0(x2)` |
| **Store** | SW | 0100011 | mem[rs1+imm] = rs2 (32-bit) | `sw x1, 0(x2)` |
| | SH | 0100011 | mem[rs1+imm] = rs2[15:0] | `sh x1, 0(x2)` |
| | SB | 0100011 | mem[rs1+imm] = rs2[7:0] | `sb x1, 0(x2)` |
| **Branch** | BEQ | 1100011 | if (rs1==rs2) PC+=imm | `beq x1, x2, label` |
| | BNE | 1100011 | if (rs1!=rs2) PC+=imm | `bne x1, x2, label` |
| | BLT | 1100011 | if (rs1<rs2) PC+=imm (signed) | `blt x1, x2, label` |
| | BGE | 1100011 | if (rs1>=rs2) PC+=imm (signed) | `bge x1, x2, label` |
| | BLTU | 1100011 | if (rs1<rs2) PC+=imm (unsigned) | `bltu x1, x2, label` |
| | BGEU | 1100011 | if (rs1>=rs2) PC+=imm (unsigned) | `bgeu x1, x2, label` |
| **Jump** | JAL | 1101111 | rd = PC+4; PC = PC+imm | `jal x1, label` |
| | JALR | 1100111 | rd = PC+4; PC = (rs1+imm) & ~1 | `jalr x1, x2, 0` |
| **Upper Imm** | LUI | 0110111 | rd = imm << 12 | `lui x1, 0x12345` |
| | AUIPC | 0010111 | rd = PC + (imm << 12) | `auipc x1, 0x12345` |

### 2.4 Cách CPU thực thi lệnh (Instruction Execution)
Mỗi lệnh RISC-V đều trải qua các bước:

1. **Fetch (Nạp lệnh):** Đọc lệnh từ bộ nhớ tại địa chỉ PC
2. **Decode (Giải mã):** Tách instruction thành opcode, funct3, funct7, rs1, rs2, rd, immediate
3. **Execute (Thực thi):** ALU tính toán (cộng, trừ, so sánh, dịch bit...)
4. **Memory (Truy cập bộ nhớ):** Load/Store đọc/ghi bộ nhớ
5. **Write-back (Ghi kết quả):** Ghi kết quả vào thanh ghi đích (rd)

---

## 3. Kiến trúc CPU ban đầu (Single-Cycle)

### 3.1 Single-Cycle là gì?
Kiến trúc single-cycle thực thi **mỗi lệnh trong 1 chu kỳ xung clock**. Tất cả 5 bước (Fetch → Decode → Execute → Memory → Write-back) xảy ra trong cùng 1 clock edge.

### 3.2 Datapath ban đầu (file `core_rv32i.v`)

```
                    ┌─────────┐
        PC ────────►│Instr Mem│────► instruction
        │           └─────────┘          │
        │                                ▼
        │           ┌──────────────────────────┐
        │           │     Instruction Decode    │
        │           │  op, f3, f7, rs1, rs2, rd│
        │           └──────────────────────────┘
        │                    │         │
        │              ┌─────▼───┐     │
        │              │ Control │     │
        │              │  Unit   │     │
        │              └─────────┘     │
        │                    │         │
        │    ┌───────────────┤         │
        │    ▼               ▼         ▼
        │ ┌──────┐    ┌──────────┐  ┌──────────┐
        │ │Sign  │    │ Register │  │   ALU    │
        │ │Extend│    │  File    │  │          │
        │ └──────┘    └──────────┘  └──────────┘
        │                                │
        │                          ┌─────▼─────┐
        │                          │  Data Mem  │
        │                          └─────┬─────┘
        │                                │
        │    ┌───────────────────────────┐│
        │    │     Write-Back Mux        ││
        │    │  ALU result / Mem data /  ││
        │    │  PC+4 / PC+imm            ││
        │    └───────────────────────────┘│
        │                                 │
        ◄─────────── PC_next ◄────────────┘
```

### 3.3 Vấn đề của Single-Cycle ban đầu
Core ban đầu dùng **Harvard Architecture** (instruction memory và data memory tách biệt), sử dụng Xilinx BRAM IP (`data_mem_core`). Điều này có nghĩa:
- Instruction memory và data memory là 2 block RAM riêng biệt
- Không thể kết nối vào bus chung của SoC (cần unified memory)
- Không có cơ chế handshake (mem_valid/mem_ready)

---

## 4. Phân tích từng module chi tiết

### 4.1 ALU (Arithmetic Logic Unit) — `alu.v`

ALU thực hiện **10 phép toán** khác nhau dựa trên tín hiệu `alucontrol[3:0]`:

| alucontrol | Phép toán | Verilog | Mô tả |
|-----------|-----------|---------|--------|
| 4'b0000 | ADD | `src1 + src2` | Cộng |
| 4'b0001 | SUB | `src1 + (~src2 + 1)` | Trừ (bù 2) |
| 4'b0010 | AND | `src1 & src2` | AND bit |
| 4'b0011 | OR | `src1 \| src2` | OR bit |
| 4'b0100 | SLL | `src1 << shamt` | Dịch trái logic |
| 4'b0101 | SLT | `$signed(src1) < $signed(src2)` | So sánh có dấu |
| 4'b0110 | SRL | `src1 >> shamt` | Dịch phải logic |
| 4'b0111 | SLTU | `src1 < src2` | So sánh không dấu |
| 4'b1000 | XOR | `src1 ^ src2` | XOR bit |
| 4'b1001 | SRA | `$signed(src1) >>> shamt` | Dịch phải arithmetic |

**Outputs bổ sung:**
- `zero`: bằng 1 khi kết quả = 0 (dùng cho BEQ/BNE)
- `last_bit`: bit cuối của kết quả (dùng cho BLT/BGE)
- `word_aligned`: kiểm tra địa chỉ word-aligned (bit[1:0] == 00)
- `halfword_aligned`: kiểm tra halfword-aligned (bit[0] == 0)

**Lưu ý kỹ thuật:**
- Phép SUB dùng `src1 + (~src2 + 1)` thay vì `src1 - src2` — đây là phép trừ bù 2 (two's complement), kết quả giống nhau nhưng phần cứng chỉ cần 1 bộ cộng
- `shamt` = `src2[4:0]` — chỉ lấy 5 bit thấp vì dịch tối đa 31 bit
- `$signed()` là directive cho Verilog biết xử lý số có dấu (signed comparison và arithmetic shift)

### 4.2 ALU Decoder — `ALU_decoder.v`

ALU Decoder chuyển đổi từ `ALUOp` (từ Main Decoder) + `funct3` + `funct7` thành `ALUControl[3:0]`:

```
ALUOp = 2'b00 → Load/Store → luôn ADD (tính địa chỉ = base + offset)
ALUOp = 2'b01 → Branch     → SUB hoặc SLT tùy loại branch
ALUOp = 2'b10 → R-type/I-type → dựa vào funct3 và funct7
```

**Kỹ thuật quan trọng:**
```verilog
wire RtypeSub = funct7[5] & opcode[5];
```
Bit `funct7[5]` = 1 cho SUB (R-type) và SRA, nhưng cũng = 1 cho SRAI (I-type).
`opcode[5]` phân biệt R-type (opcode=0110011, bit5=1) vs I-type (opcode=0010011, bit5=0).
Nên `RtypeSub` chỉ = 1 khi thực sự là R-type SUB hoặc R-type SRA.

### 4.3 Main Decoder — `Main_decoder.v`

Main Decoder tạo ra **tất cả tín hiệu điều khiển** từ opcode. Sử dụng kỹ thuật "packed control word" — gom tất cả tín hiệu thành 1 vector 14-bit:

```verilog
// Thứ tự: RegWrite[1] | ImmSrc[3] | MemWrite[1] | ResultSrc[2] | Branch[1] | ALUOp[2] | ALUSrc[1] | Jump[1] | SecondPC[2]
//          13           12:10        9              8:7            6           5:4        3           2         1:0
assign {RegWrite, ImmSrc, MemWrite, ResultSrc, Branch, ALUOp, ALUSrc, Jump, SecondPC} = controls;
```

**Bảng tín hiệu điều khiển:**

| Tín hiệu | Bit | Mô tả |
|-----------|-----|--------|
| RegWrite | 1-bit | Cho phép ghi vào register file |
| ImmSrc | 3-bit | Chọn loại immediate (I/S/B/J/U) |
| MemWrite | 1-bit | Cho phép ghi data memory |
| ResultSrc | 2-bit | Chọn nguồn write-back (ALU/Mem/PC+4/PC+imm) |
| Branch | 1-bit | Đây là lệnh branch |
| ALUOp | 2-bit | Loại phép toán cho ALU decoder |
| ALUSrc | 1-bit | Nguồn toán hạng 2 của ALU (register hoặc immediate) |
| Jump | 1-bit | Đây là lệnh nhảy (JAL/JALR) |
| SecondPC | 2-bit | Nguồn tính PC đích nhảy |

**Bảng SecondPC:**

| SecondPC | Công thức | Dùng cho |
|----------|-----------|----------|
| 2'b00 | PC + immediate | Branch, JAL |
| 2'b01 | immediate (trực tiếp) | LUI |
| 2'b10 | (rs1 + immediate) & ~1 | JALR |

### 4.4 Control Top — `control_top.v`

Module này kết hợp Main Decoder + ALU Decoder, và thêm **Branch Resolution Logic**:

```verilog
always @(*) begin
    case(funct3)
        3'b000:        a_branch = alu_zero & Branch;       // BEQ: nhảy nếu bằng
        3'b001:        a_branch = ~alu_zero & Branch;      // BNE: nhảy nếu khác
        3'b100, 3'b110: a_branch = alu_last_bit & Branch;  // BLT/BLTU: nhảy nếu nhỏ hơn
        3'b101, 3'b111: a_branch = ~alu_last_bit & Branch; // BGE/BGEU: nhảy nếu >= 
        default:       a_branch = 1'b0;
    endcase
end
assign PCSrc = a_branch | Jump;
```

**Giải thích chi tiết Branch Logic:**

Khi gặp lệnh branch, ALU thực hiện phép trừ/so sánh giữa rs1 và rs2:
- **BEQ** (funct3=000): ALU trừ → nếu kết quả = 0 (`alu_zero=1`) → bằng nhau → nhảy
- **BNE** (funct3=001): ALU trừ → nếu kết quả ≠ 0 (`alu_zero=0`) → khác nhau → nhảy
- **BLT** (funct3=100): ALU so sánh signed → nếu `result[0]=1` (src1 < src2) → nhảy
- **BGE** (funct3=101): ngược với BLT → nếu `result[0]=0` → nhảy
- **BLTU** (funct3=110): ALU so sánh unsigned → tương tự BLT
- **BGEU** (funct3=111): ngược với BLTU

### 4.5 Register File — `Regfile.v`

```verilog
reg [31:0] Register [0:31];  // 32 thanh ghi, 32-bit mỗi cái
```

**Đặc điểm:**
- **2 port đọc** (combinational — không cần clock): `rd1 = Register[a1]`, `rd2 = Register[a2]`
- **1 port ghi** (synchronous — ghi ở cạnh lên clock): `Register[a3] <= wd3`
- **Bảo vệ x0**: `if (we3 && a3 != 5'd0)` — không bao giờ ghi vào x0
- **Reset đồng bộ**: khi `rst=1`, tất cả 32 thanh ghi reset về 0

**Tại sao đọc combinational?**
Vì trong cùng 1 chu kỳ, ngay khi lệnh được decode (biết rs1, rs2), cần đọc thanh ghi **ngay lập tức** để đưa vào ALU. Nếu đọc synchronous (chờ clock edge) thì mất thêm 1 cycle.

### 4.6 Sign Extend — `SignExtend.v`

Module mở rộng immediate từ các format khác nhau thành 32-bit:

```
input [24:0] instr = instruction[31:7]  (25 bit cao của lệnh)
```

| immsrc | Loại | Cách mở rộng | Lệnh dùng |
|--------|------|-------------|-----------|
| 3'b000 | I-type | `{20×sign, instr[24:13]}` | ADDI, LW, JALR... |
| 3'b001 | S-type | `{20×sign, instr[24:18], instr[4:0]}` | SW, SH, SB |
| 3'b010 | B-type | `{20×sign, instr[0], instr[23:18], instr[4:1], 0}` | BEQ, BNE... |
| 3'b011 | J-type | `{12×sign, instr[12:5], instr[13], instr[23:14], 0}` | JAL |
| 3'b100 | U-type | `{instr[24:5], 12'b0}` | LUI, AUIPC |

**Sign Extension (Mở rộng dấu):** Bit cao nhất (bit dấu) được nhân bản lên các bit phía trên.
Ví dụ: immediate 12-bit = `0xFFF` (-1 signed) → mở rộng thành 32-bit = `0xFFFFFFFF` (-1).
Nếu không sign-extend, `0xFFF` sẽ thành `0x00000FFF` (4095) — sai hoàn toàn!

### 4.7 Load/Store Decoder — `load_store_decoder.v`

Module này xử lý **byte addressing** — cho phép đọc/ghi 1 byte, 2 bytes (halfword), hoặc 4 bytes (word) tại bất kỳ vị trí nào trong word 32-bit.

**Byte Enable:**
Bộ nhớ 32-bit được chia thành 4 byte lanes:
```
Byte 3 (bit 31:24) | Byte 2 (bit 23:16) | Byte 1 (bit 15:8) | Byte 0 (bit 7:0)
     be[3]=1            be[2]=1               be[1]=1             be[0]=1
```

Ví dụ: `SB x1, 2(x2)` — ghi 1 byte tại offset 2 trong word:
- `offset = address[1:0] = 2'b10`
- `byte_enable = 4'b0100` (chỉ byte 2)
- `data = (reg_read & 0xFF) << 16` (dịch byte vào vị trí byte 2)

### 4.8 Reader — `Reader.v`

Module đọc dữ liệu từ memory, dịch về đúng vị trí, và thực hiện sign/zero extension:

```
Luồng xử lý:
1. Mask: chỉ lấy bytes theo byte_enable
2. Shift: dịch byte về vị trí thấp  
3. Sign Extend: mở rộng 8→32 hoặc 16→32 bit
```

Ví dụ: `LB x1, 2(x2)` — đọc 1 byte signed tại offset 2:
1. `be_mask = 4'b0100` → `masked_data = {0, mem_data[23:16], 0, 0}`
2. Shift right 16 bits → `raw_data = {0, 0, 0, mem_data[23:16]}`
3. Sign extend: `wb_data = {{24{raw_data[7]}}, raw_data[7:0]}`

**Phân biệt `f3[2]`:**
- `f3[2] = 0` → LB, LH (signed) → sign extension
- `f3[2] = 1` → LBU, LHU (unsigned) → zero extension

---

## 5. Các bug đã phát hiện và cách sửa

### Bug #1: LUI và AUIPC — Kết quả ghi sai

**Vấn đề:**
```verilog
// core_rv32i.v (trước khi sửa)
2'b11: begin
    write_back_data = pc_next;  // BUG! pc_next = PC+4, không phải kết quả LUI/AUIPC
    wb_valid = 1'b1;
end
```

LUI cần ghi `immediate` (giá trị 20-bit dịch trái 12 bit) vào rd.
AUIPC cần ghi `PC + immediate` vào rd.

**Cách sửa (trong rv32i_bus.v):**
```verilog
2'b11: begin
    write_back_data = pc_plus_second;  // LUI: immediate, AUIPC: pc + immediate
    wb_valid = 1'b1;
end
```

**Phối hợp với SecondPC:**
- LUI:   SecondPC=2'b01 → `pc_plus_second = immediate` ✓
- AUIPC: SecondPC=2'b00 → `pc_plus_second = PC + immediate` ✓

### Bug #2: AUIPC SecondPC sai

**Vấn đề:**
```verilog
// Main_decoder.v (trước khi sửa)
7'b0010111: controls = 14'b...01; // AUIPC: SecondPC=01 → immediate (SAI!)
```

AUIPC = Add Upper Immediate to PC → kết quả phải là `PC + (imm << 12)`.

**Cách sửa:**
```verilog
7'b0110111: controls = 14'b...01; // LUI: SecondPC=01 → immediate ✓
7'b0010111: controls = 14'b...00; // AUIPC: SecondPC=00 → PC + immediate ✓
```

### Bug #3: JALR không clear bit 0

**Theo RISC-V spec (Section 2.5):**
> The target address is obtained by adding the sign-extended 12-bit I-immediate to the register rs1, then setting the least-significant bit of the result to zero.

**Vấn đề:**
```verilog
// core_rv32i.v (trước khi sửa)
2'b10: pc_plus_second_add = read_reg1 + immediate;  // Không clear LSB!
```

Nếu rs1 + imm = lẻ → PC sẽ trỏ đến địa chỉ lẻ → crash!

**Cách sửa (trong rv32i_bus.v):**
```verilog
2'b10: pc_plus_second = (read_reg1 + immediate) & 32'hFFFFFFFE;  // Clear bit 0
```

`& 32'hFFFFFFFE` tương đương với `& ~1` — xóa bit cuối cùng, đảm bảo địa chỉ luôn chẵn.

### Bug #4: Thiếu dấu `:` sau `default` trong Main Decoder

**Vấn đề:**
```verilog
default controls = 14'b0...;  // Lỗi cú pháp! Thiếu dấu :
```

Trong Verilog, `case` statement yêu cầu `:` sau mỗi label, kể cả `default`.

**Cách sửa:**
```verilog
default: controls = 14'b0...;  // Thêm dấu :
```

### Bug #5: Inferred Latches trong Reader và Load/Store Decoder

**Inferred Latch là gì?**
Khi dùng `always @(*)` (combinational logic) mà không gán giá trị cho output trong MỌI trường hợp, Verilog sẽ tự tạo **latch** — một phần tử nhớ giữ giá trị cũ. Latch là nguy hiểm vì:
- Tạo ra timing không thể dự đoán
- Synthesis tool tạo ra phần cứng không mong muốn
- Rất khó debug

**Vấn đề trong Reader.v:**
```verilog
F3_BYTE, F3_BYTE_U: begin
    case (be_mask)
        4'b0001: raw_data = masked_data;
        4'b0010: raw_data = masked_data >> 8;
        // ...
        // default: raw_data = 32'd0;  ← BỊ COMMENT! Nếu be_mask khác → giữ giá trị cũ → LATCH!
    endcase
end
```

**Vấn đề trong load_store_decoder.v:**
```verilog
default: begin
    byte_enable = 4'b0000;
    // data không được gán → LATCH cho data!
end
```

**Cách sửa:**
1. Luôn gán giá trị mặc định ở đầu `always` block:
   ```verilog
   always @(*) begin
       raw_data = 32'd0;  // Mặc định → không tạo latch
       case (...)
           ...
       endcase
   end
   ```
2. Hoặc thêm `default` case đầy đủ cho mọi output.

---

## 6. Kiến trúc CPU mới (Multi-Cycle Bus Wrapper)

### 6.1 Tại sao cần chuyển sang Multi-Cycle?

| Yêu cầu SoC | Single-Cycle | Multi-Cycle |
|-------------|-------------|-------------|
| Bus handshake (mem_valid/mem_ready) | ✗ Không có | ✓ Có |
| Unified memory (code + data chung bus) | ✗ Harvard | ✓ Von Neumann |
| Memory-mapped I/O | ✗ Không | ✓ Có |
| Chờ peripheral chậm (UART...) | ✗ Không thể | ✓ Stall tự động |

### 6.2 State Machine — Trái tim của rv32i_bus.v

```
            ┌────────────────────────────────────────────────────────────┐
            │                                                            │
            │  ┌──────────┐     mem_ready      ┌───────────┐            │
  Reset ───►│  │ S_FETCH  │────────────────────►│ S_EXECUTE │            │
            │  │          │◄───────────────────┐│           │            │
            │  │ Yêu cầu  │  non-mem instr     ││ Decode +  │            │
            │  │ đọc lệnh │  (ADD, BEQ...)     ││ ALU +     │            │
            │  │ từ bus    │                    ││ Write-back│            │
            │  └──────────┘◄─────────────┐     │└─────┬─────┘            │
            │                             │     │      │                  │
            │                             │     │      │ mem instr        │
            │                             │     │      │ (LW, SW...)      │
            │                             │     │      ▼                  │
            │                             │     │ ┌──────────┐           │
            │                             │     │ │ S_MEMREQ │           │
            │                             └─────┘ │          │           │
            │                              mem_   │ Đợi      │           │
            │                              ready  │ mem_ready│           │
            │                                     └──────────┘           │
            │                                                            │
            └────────────────────────────────────────────────────────────┘
```

### 6.3 Chi tiết từng state

#### State 0: S_FETCH (Nạp lệnh)
```verilog
S_FETCH: begin
    mem_valid <= 1'b1;    // "Tôi muốn truy cập bus"
    mem_instr <= 1'b1;    // "Đây là instruction fetch"
    mem_addr  <= pc;      // "Cho tôi lệnh tại địa chỉ PC"
    mem_wstrb <= 4'b0000; // "Tôi đọc, không ghi" (wstrb=0 → read)
    
    if (mem_ready) begin           // Khi bus trả lời
        instruction <= mem_rdata;  // Lưu lệnh vào register
        mem_valid   <= 1'b0;      // Xong, nhả bus
        state       <= S_EXECUTE;  // Sang bước tiếp
    end
end
```

**Giải thích `mem_valid` / `mem_ready`:**
- CPU đặt `mem_valid = 1` + `mem_addr` → "Tôi cần dữ liệu"
- Bus nhận, gửi request đến đúng slave (SRAM/UART/LED...)
- Slave đặt dữ liệu lên `mem_rdata` + `ready = 1` → "Dữ liệu sẵn sàng"
- CPU đọc `mem_rdata`, xong đặt `mem_valid = 0`

#### State 1: S_EXECUTE (Giải mã + Thực thi)
```verilog
S_EXECUTE: begin
    if (need_mem_access) begin
        // Lệnh load/store → cần truy cập bus thêm lần nữa
        mem_valid <= 1'b1;
        mem_instr <= 1'b0;                              // "Đây là data access"
        mem_addr  <= {alu_result[31:2], 2'b00};         // Địa chỉ word-aligned
        mem_wstrb <= mem_write_ctrl ? byte_enable : 4'b0000;  // Store → ghi; Load → đọc
        mem_wdata <= store_data;
        state     <= S_MEMREQ;
    end else begin
        // Lệnh ALU/Branch/Jump → hoàn thành ngay
        do_reg_write   <= reg_write_ctrl & wb_valid;
        reg_write_data <= write_back_data;
        pc             <= pc_next;
        state          <= S_FETCH;  // Fetch lệnh tiếp
    end
end
```

**Tại sao `{alu_result[31:2], 2'b00}`?**
Đây là kỹ thuật **word-alignment** — xóa 2 bit thấp để địa chỉ luôn chia hết cho 4. BRAM trên FPGA thường chỉ hỗ trợ truy cập word-aligned, byte selection dùng `byte_enable`.

#### State 2: S_MEMREQ (Đợi bộ nhớ)
```verilog
S_MEMREQ: begin
    if (mem_ready) begin
        do_reg_write   <= reg_write_ctrl & wb_valid;
        reg_write_data <= write_back_data;
        pc             <= pc_next;
        mem_valid      <= 1'b0;
        state          <= S_FETCH;
    end
    // Nếu chưa ready → ở lại state này (stall)
end
```

### 6.4 Instruction reset: NOP
```verilog
instruction <= 32'h00000013;  // addi x0, x0, 0 → NOP
```
Khi reset, instruction register chứa NOP (No Operation) — lệnh không làm gì. Điều này đảm bảo control signals an toàn trước khi fetch xong lệnh đầu tiên.

### 6.5 Tại sao cần latch instruction?
Trong single-cycle, instruction memory đọc combinational → lệnh luôn sẵn sàng. Trong multi-cycle, bus trả lệnh qua `mem_rdata` — tín hiệu này thay đổi khi bus xử lý request khác. Nên phải **latch** (lưu) vào register `instruction`.

---

## 7. Hệ thống SoC Tang Nano 9K

### 7.1 Các peripheral

#### SRAM — 8KB (file `sram.v`)
- 4 Gowin_SP BRAM instances — mỗi cái chứa 1 byte lane (byte 0, 1, 2, 3)
- Tổng: 4 × 2048 words × 8 bits = 8192 bytes
- Dùng chung cho cả instruction và data
- Khởi tạo nội dung từ file `mem_init.v` (chứa firmware C đã biên dịch)
- `sram_ready` delay 1 cycle sau `sram_sel` (vì BRAM đọc synchronous)

#### LEDs — 6-bit (file `tang_nano_9k_leds.v`)
- Thanh ghi 6-bit điều khiển 6 LED trên board
- Đọc/ghi tại địa chỉ `0x80000000`
- `leds_ready = leds_sel` → trả lời ngay (ready cùng cycle)
- `leds = ~leds_data_o[5:0]` — đảo bit vì LED trên Tang Nano 9K active-low

#### UART (file `simpleuart.v` + `uart_wrap.v`)
- UART transceiver từ PicoSoC
- 2 thanh ghi: DIV (baud rate divider) tại `0x80000008`, DAT (data) tại `0x8000000C`
- Ghi vào DAT → gửi byte qua TX
- Đọc DAT → nhận byte từ RX (-1 nếu chưa có)
- `uart_ready` delay cho đến khi transmit xong (nếu đang gửi)

#### Countdown Timer (file `countdown_timer.v`)
- Thanh ghi 32-bit đếm ngược, dừng tại 0
- Ghi giá trị → bắt đầu đếm ngược
- Đọc → giá trị hiện tại
- Có state machine delay 2-3 cycle trước khi ready (over-engineered design by original author)

#### I2C GPIO (file `i2c_gpio.v`)
- Bit-bang I2C qua 2 GPIO pin
- Ghi: bit[0] = SCL, bit[1] = SDA
- Đọc: trạng thái thực tế của SCL/SDA pin
- Open-drain: `i2c_scl = i2c_scl_o ? 1'bz : 1'b0` (high-Z hoặc kéo thấp)

### 7.2 Address Decoder

```verilog
assign sram_sel = mem_valid && (mem_addr < 32'h00002000);                    // 0x0000_0000 - 0x0000_1FFF
assign leds_sel = mem_valid && (mem_addr == 32'h80000000);                   // 0x8000_0000
assign uart_sel = mem_valid && ((mem_addr & 32'hfffffff8) == 32'h80000008);  // 0x8000_0008 - 0x8000_000F
assign cdt_sel  = mem_valid && (mem_addr == 32'h80000010);                   // 0x8000_0010
assign i2c_sel  = mem_valid && (mem_addr == 32'h80000020);                   // 0x8000_0020
```

**Read data mux:**
```verilog
assign mem_rdata = sram_sel ? sram_data_o :
                   leds_sel ? leds_data_o :
                   uart_sel ? uart_data_o :
                   cdt_sel  ? cdt_data_o  :
                   i2c_sel  ? i2c_data_o  : 32'h0;
```

### 7.3 Reset Controller (file `reset.v`)
```verilog
reg [5:0] reset_count = 0;
assign reset_n = &reset_count;  // reset_n = 1 chỉ khi tất cả 6 bit = 1 (count = 63)
```
Sau khi nhấn nút reset, bộ đếm chạy từ 0 → 63 (64 cycles), sau đó `reset_n` lên 1 — đảm bảo tất cả module đã ổn định trước khi CPU bắt đầu.

---

## 8. Memory Map và Bus Protocol

### 8.1 Memory Map chi tiết

```
 Địa chỉ          │ Kích thước │ Peripheral      │ Quyền │ Mô tả
 ──────────────────┼────────────┼─────────────────┼────────┼──────────────────────────
 0x0000_0000       │   8 KB     │ SRAM            │ RW     │ Code + Data + Stack
   0x0000_0000     │            │   .text          │ R      │ Vùng code (firmware)
   ~0x0000_1E00    │            │   Stack top      │ RW     │ Stack (grow down từ 8192)
 0x0000_2000-      │            │ (unmapped)       │ --     │ Truy cập = bus hang
   0x7FFF_FFFF     │            │                  │        │
 0x8000_0000       │   4 B      │ LEDs            │ RW     │ 6-bit LED control
 0x8000_0008       │   4 B      │ UART DIV        │ RW     │ Baud rate divider
 0x8000_000C       │   4 B      │ UART DAT        │ RW     │ TX/RX data
 0x8000_0010       │   4 B      │ Countdown Timer │ RW     │ 32-bit countdown
 0x8000_0020       │   4 B      │ I2C GPIO        │ RW     │ SCL/SDA bit-bang
```

### 8.2 Bus Protocol (mem_valid / mem_ready handshake)

```
Giao dịch Read (ví dụ: LW):
             _______________
mem_valid  _|               |________
             _______________
mem_addr   _X____addr_______X________
             
mem_wstrb  _________0000_____________ (wstrb=0 → read)
                         ___
mem_ready  _____________|   |________
                         ___
mem_rdata  _____________X dat X________ 

clk        _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
           T0   T1   T2   T3   T4

Giao dịch Write (ví dụ: SW):
             _______________
mem_valid  _|               |________
             _______________
mem_addr   _X____addr_______X________
             _______________
mem_wstrb  _X____1111_______X________ (wstrb≠0 → write)
             _______________
mem_wdata  _X____data_______X________
                         ___
mem_ready  _____________|   |________

clk        _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
           T0   T1   T2   T3   T4
```

**Quy tắc:**
1. CPU đặt `mem_valid=1` cùng addr/wdata/wstrb
2. CPU giữ nguyên cho đến khi thấy `mem_ready=1`
3. Khi `mem_ready=1`, giao dịch hoàn thành
4. CPU đặt `mem_valid=0`
5. `mem_wstrb=0` → read, `mem_wstrb≠0` → write (byte enable)

---

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

### 11.3 Các vấn đề tiềm ẩn

1. **Bus hang:** Nếu CPU truy cập địa chỉ unmapped (không có slave nào trả ready) → CPU treo vĩnh viễn ở S_FETCH hoặc S_MEMREQ. PicoRV32 có timeout → trap.

2. **Misaligned access:** Nếu LW vào địa chỉ không chia hết cho 4 → byte_enable sai → đọc sai dữ liệu. PicoRV32 phát hiện và trap.

3. **Sign extension trong SignExtend.v:** Thiếu `:` sau `default` (tương tự bug #4):
   ```verilog
   default immext = 32'b0;  // Nên là: default: immext = 32'b0;
   ```

---

## 12. Hướng phát triển

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

---

## 13. Tổng kết kiến thức Verilog đã sử dụng

### 13.1 Combinational vs Sequential Logic

```verilog
// Combinational (không có clock, tính ngay):
always @(*) begin
    result = a + b;  // Dùng = (blocking assignment)
end

// Sequential (chờ clock edge, lưu trữ):
always @(posedge clk) begin
    result <= a + b;  // Dùng <= (non-blocking assignment)
end
```

**Quy tắc vàng:**
- `always @(*)` + `=` → combinational logic (tổ hợp)
- `always @(posedge clk)` + `<=` → sequential logic (tuần tự)
- KHÔNG BAO GIỜ trộn `=` và `<=` trong cùng 1 always block

### 13.2 Inferred Latch (Đã gặp ở Bug #5)

```verilog
// BUG: tạo latch cho y
always @(*) begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        // Thiếu 2'b10 và 2'b11 → y giữ giá trị cũ → LATCH!
    endcase
end

// FIX: thêm default hoặc gán mặc định
always @(*) begin
    y = 32'd0;  // Mặc định
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
    endcase
end
```

### 13.3 Parameter và Module Instantiation

```verilog
// Khai báo module có parameter:
module rv32i_bus #(
    parameter [31:0] STACKADDR = 32'hffff_ffff
) (
    input clk, ...
);

// Instantiation với parameter override:
rv32i_bus #(.STACKADDR(8192)) cpu (.clk(clk), ...);
```

### 13.4 Wire vs Reg

```verilog
wire [31:0] a;   // Kết nối dây, dùng với assign hoặc output của module
reg  [31:0] b;   // Lưu trữ giá trị, dùng trong always block

assign a = x + y;     // wire dùng assign
always @(*) b = x + y; // reg dùng trong always
```

**Lưu ý:** `reg` trong Verilog KHÔNG nhất thiết tạo ra register phần cứng.
Nếu dùng trong `always @(*)` → tổ hợp (combinational).
Nếu dùng trong `always @(posedge clk)` → flip-flop (sequential).

### 13.5 Các toán tử quan trọng

```verilog
&  → AND bit             | → OR bit              ^ → XOR bit
~  → NOT bit             << → Shift left          >> → Shift right (logic)
>>> → Shift right (arithmetic, giữ dấu)
$signed() → Ép signed     {,} → Concatenate        {{}} → Replicate

// Ví dụ sign extension:
{{20{instr[24]}}, instr[24:13]}
// Lấy bit 24 (bit dấu), nhân bản 20 lần, nối với 12 bit immediate
```

### 13.6 Case Statement

```verilog
case (selector)
    VALUE1: statement1;
    VALUE2: statement2;
    default: default_statement;  // LUÔN có default để tránh latch!
endcase

// casez: dùng z/? là don't care
// casex: dùng x/z là don't care (nguy hiểm, tránh dùng)
```

### 13.7 Localparam vs Parameter

```verilog
parameter X = 10;       // Có thể override khi instantiate
localparam Y = 20;      // Không thể override (hằng số local)
```

### 13.8 Blocking (=) vs Non-blocking (<=)

```verilog
// Blocking: thực thi tuần tự (dòng trên xong mới tới dòng dưới)
a = 1;
b = a;  // b = 1

// Non-blocking: thực thi song song (gán đồng thời ở cuối time step)
a <= 1;
b <= a;  // b = giá trị CŨ của a (trước khi a=1)
```

---

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

---

## Phụ lục A: Sơ đồ kết nối tín hiệu hoàn chỉnh

```
rv32i_bus                         SoC top.v
┌────────────────┐               ┌──────────────────────────────────┐
│                │  mem_valid     │                                  │
│  state machine │──────────────►│  Address Decoder                 │
│                │  mem_instr     │  ┌─────────────┐                │
│  ┌──────────┐  │──────────────►│  │ sram_sel     │──► SRAM       │
│  │ S_FETCH  │  │  mem_addr     │  │ leds_sel     │──► LEDs       │
│  │ S_EXECUTE│  │──────────────►│  │ uart_sel     │──► UART       │
│  │ S_MEMREQ │  │  mem_wdata    │  │ cdt_sel      │──► Timer      │
│  └──────────┘  │──────────────►│  │ i2c_sel      │──► I2C GPIO   │
│                │  mem_wstrb     │  └─────────────┘                │
│  ┌──────────┐  │──────────────►│                                  │
│  │ control  │  │               │  mem_rdata = mux(sram/led/uart/  │
│  │ ALU      │  │  mem_rdata    │              timer/i2c)          │
│  │ regfile  │  │◄──────────────│                                  │
│  │ signext  │  │  mem_ready    │  mem_ready = valid & (sram_rdy   │
│  │ LS_dec   │  │◄──────────────│             | led_rdy | uart_rdy │
│  │ reader   │  │               │             | cdt_rdy | i2c_rdy) │
│  └──────────┘  │  clk          │                                  │
│                │◄──────────────│  27 MHz crystal                  │
│                │  resetn       │                                  │
│                │◄──────────────│  reset_control                   │
└────────────────┘               └──────────────────────────────────┘
```

---

## Phụ lục B: Bảng trạng thái đầy đủ của State Machine

| State hiện tại | Điều kiện | Hành động | State tiếp |
|---------------|-----------|-----------|------------|
| S_FETCH | `~resetn` | Reset tất cả registers | S_FETCH |
| S_FETCH | `mem_ready=0` | Giữ mem_valid=1, chờ | S_FETCH |
| S_FETCH | `mem_ready=1` | Latch instruction, mem_valid=0 | S_EXECUTE |
| S_EXECUTE | `need_mem=0` | Write-back, update PC | S_FETCH |
| S_EXECUTE | `need_mem=1` | Đặt mem_valid=1 cho load/store | S_MEMREQ |
| S_MEMREQ | `mem_ready=0` | Giữ mem_valid=1, chờ | S_MEMREQ |
| S_MEMREQ | `mem_ready=1` | Write-back, update PC, mem_valid=0 | S_FETCH |

---

*Báo cáo được tạo ngày 06/04/2026*
*Core tự thiết kế bởi tác giả, integrated bởi AI assistant*
*Target platform: Sipeed Tang Nano 9K (Gowin GW1NR-9C)*
