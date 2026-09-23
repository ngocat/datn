/* rv32i_bus.v - Multi-cycle RV32I core with picorv32-compatible bus interface
 *
 * Drop-in replacement for picorv32 in the Tang Nano 9K SoC.
 * Uses the same mem_valid/mem_ready handshake protocol.
 *
 * Architecture: 3-state machine (FETCH -> EXECUTE -> MEMREQ)
 *   - Non-memory instructions: ~4 CPI
 *   - Load/Store instructions: ~5-6 CPI
 *
 * Unused picorv32 parameters are accepted for compatibility but ignored.
 */

module rv32i_bus #(
    parameter [31:0] STACKADDR      = 32'hffff_ffff,
    parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] PROGADDR_IRQ   = 32'h0000_0000,
    parameter [0:0]  BARREL_SHIFTER   = 0,
    parameter [0:0]  COMPRESSED_ISA   = 0,
    parameter [0:0]  ENABLE_MUL       = 0,
    parameter [0:0]  ENABLE_DIV       = 0,
    parameter [0:0]  ENABLE_FAST_MUL  = 0,
    parameter [0:0]  ENABLE_IRQ       = 0,
    parameter [0:0]  ENABLE_IRQ_QREGS = 0
) (
    input             clk,
    input             resetn,
    output reg        trap, // not use

    output reg        mem_valid,
    output reg        mem_instr, // not use
    input             mem_ready,

    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0]  mem_wstrb,
    input      [31:0] mem_rdata,

    input      [31:0] irq, // not use
    output     [31:0] eoi // not use
);

    // IRQ not supported in this simple core
    assign eoi = 32'd0;

    // ================================================================
    // State machine definitions
    // ================================================================
    localparam S_FETCH   = 2'd0;
    localparam S_EXECUTE = 2'd1;
    localparam S_MEMREQ  = 2'd2;

    reg [1:0]  state;
    reg [31:0] pc;
    reg [31:0] instruction;

    // ================================================================
    // Instruction decode (from latched instruction register)
    // ================================================================
    wire [6:0]  op       = instruction[6:0];
    wire [2:0]  f3       = instruction[14:12];
    wire [6:0]  f7       = instruction[31:25];
    wire [4:0]  rs1_addr = instruction[19:15];
    wire [4:0]  rs2_addr = instruction[24:20];
    wire [4:0]  rd_addr  = instruction[11:7];
    wire [24:0] raw_imm  = instruction[31:7];

    // ================================================================
    // Control signals (combinational from instruction)
    // ================================================================
    wire        reg_write_ctrl;
    wire        alu_source;
    wire        mem_write_ctrl;
    wire        pc_src;
    wire [2:0]  imm_source;
    wire [3:0]  alu_control;
    wire [1:0]  second_pc_src;
    wire [1:0]  result_src;

    // ALU flags
    wire alu_zero;
    wire alu_last_bit;

    // ================================================================
    // Datapath wires
    // ================================================================
    wire [31:0] read_reg1, read_reg2;
    wire [31:0] immediate;
    wire [31:0] alu_result;
    wire [3:0]  byte_enable;
    wire [31:0] store_data;
    wire [31:0] load_wb_data;
    wire        load_wb_valid;

    // ================================================================
    // Register write control
    // ================================================================
    reg         do_reg_write;
    reg  [31:0] reg_write_data;

    // ================================================================
    // ALU source mux
    // ================================================================
    reg [31:0] alu_src2;
    always @(*) begin
        case (alu_source)
            1'b1:    alu_src2 = immediate;
            default: alu_src2 = read_reg2;
        endcase
    end

    // ================================================================
    // PC calculation
    // ================================================================
    reg [31:0] pc_next;
    reg [31:0] pc_plus_second;

    always @(*) begin
        case (second_pc_src)
            2'b00:   pc_plus_second = pc + immediate;
            2'b01:   pc_plus_second = immediate;
            2'b10:   pc_plus_second = (read_reg1 + immediate) & 32'hFFFFFFFE;
            default: pc_plus_second = 32'd0;
        endcase
    end

    always @(*) begin
        case (pc_src)
            1'b1:    pc_next = pc_plus_second;
            default: pc_next = pc + 32'd4;
        endcase
    end

    // ================================================================
    // Write-back mux
    // ================================================================
    reg [31:0] write_back_data;
    reg        wb_valid;
    always @(*) begin
        case (result_src)
            2'b00: begin write_back_data = alu_result;     wb_valid = 1'b1;         end
            2'b01: begin write_back_data = load_wb_data;   wb_valid = load_wb_valid; end
            2'b10: begin write_back_data = pc + 32'd4;     wb_valid = 1'b1;         end
            2'b11: begin write_back_data = pc_plus_second; wb_valid = 1'b1;         end
        endcase
    end

    // Need memory access? (load or store)
    wire need_mem_access = mem_write_ctrl || (result_src == 2'b01);

    // ================================================================
    // Submodule instantiations
    // ================================================================

    control Control(
        .Op(op), .funct7(f7), .funct3(f3),
        .alu_zero(alu_zero), .alu_last_bit(alu_last_bit),
        .RegWrite(reg_write_ctrl), .ALUSrc(alu_source),
        .MemWrite(mem_write_ctrl), .ResultSrc(result_src),
        .PCSrc(pc_src), .ImmSrc(imm_source),
        .ALUControl(alu_control), .SecondPC(second_pc_src)
    );

    ALU alu_inst(
        .src1(read_reg1), .src2(alu_src2),
        .alucontrol(alu_control),
        .alu_result(alu_result),
        .zero(alu_zero), .last_bit(alu_last_bit),
        .word_aligned(), .halfword_aligned()
    );

    regfile Regfile(
        .clk(clk), .rst(~resetn),
        .we3(do_reg_write),
        .a1(rs1_addr), .a2(rs2_addr), .a3(rd_addr),
        .wd3(reg_write_data),
        .rd1(read_reg1), .rd2(read_reg2)
    );

    signextend SignExt(
        .instr(raw_imm), .immsrc(imm_source), .immext(immediate)
    );

    load_store_decoder LSDecoder(
        .alu_result_address(alu_result),
        .f3(f3), .reg_read(read_reg2),
        .byte_enable(byte_enable), .data(store_data)
    );

    reader Reader(
        .mem_data(mem_rdata),
        .be_mask(byte_enable),
        .f3(f3),
        .wb_data(load_wb_data),
        .valid(load_wb_valid)
    );

    // ================================================================
    // State machine
    // ================================================================
    always @(posedge clk) begin
        if (~resetn) begin
            state          <= S_FETCH;
            pc             <= PROGADDR_RESET;
            instruction    <= 32'h00000013;
            mem_valid      <= 1'b0;
            mem_instr      <= 1'b0;
            mem_addr       <= 32'd0;
            mem_wdata      <= 32'd0;
            mem_wstrb      <= 4'b0000;
            do_reg_write   <= 1'b0;
            reg_write_data <= 32'd0;
            trap           <= 1'b0;
        end else begin
            do_reg_write <= 1'b0;

            case (state)
                // ---- FETCH: request instruction from bus ----
                S_FETCH: begin
                    mem_valid <= 1'b1;
                    mem_instr <= 1'b1;
                    mem_addr  <= pc;
                    mem_wstrb <= 4'b0000;
                    if (mem_ready) begin
                        instruction <= mem_rdata;
                        mem_valid   <= 1'b0;
                        state       <= S_EXECUTE;
                    end
                end

                // ---- EXECUTE: decode + ALU, decide next ----
                S_EXECUTE: begin
                    if (need_mem_access) begin
                        mem_valid <= 1'b1;
                        mem_instr <= 1'b0;
                        mem_addr  <= {alu_result[31:2], 2'b00};
                        mem_wstrb <= mem_write_ctrl ? byte_enable : 4'b0000;
                        mem_wdata <= store_data;
                        state     <= S_MEMREQ;
                    end else begin
                        do_reg_write   <= reg_write_ctrl & wb_valid;
                        reg_write_data <= write_back_data;
                        pc             <= pc_next;
                        state          <= S_FETCH;
                    end
                end

                // ---- MEMREQ: wait for data memory response ----
                S_MEMREQ: begin
                    if (mem_ready) begin
                        do_reg_write   <= reg_write_ctrl & wb_valid;
                        reg_write_data <= write_back_data;
                        pc             <= pc_next;
                        mem_valid      <= 1'b0;
                        state          <= S_FETCH;
                    end
                end

                default: begin
                    state <= S_FETCH;
                end
            endcase
        end
    end

endmodule
