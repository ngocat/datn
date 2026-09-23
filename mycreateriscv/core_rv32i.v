`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:20:04 09/04/2025 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top( 
	input wire clk,
   input wire rst_n,
	output wire [31:0] debug_pc
);

/**
* PROGRAM COUNTER
*/

wire [31:0] pc ;
reg [31:0] pc_next;
reg [31:0] pc_plus_second_add;
assign debug_pc = pc;
wire [31:0] instruction;
wire [31:0] instr_raw;
	 
wire [6:0] op; assign op = instruction[6:0];
wire [2:0] f3; assign f3 = instruction[14:12];
wire [6:0] f7; assign f7 = instruction[31:25];
wire alu_zero;
wire alu_last_bit;
wire [3:0] alu_control;
wire [2:0] imm_source;
wire mem_write;
wire reg_write;
wire alu_source;
wire [1:0] ResultSrc;
wire PCSrc;
wire [1:0] second_add_source;
	 
wire [4:0] source_reg1; assign source_reg1 = instruction[19:15];
wire [4:0] source_reg2; assign source_reg2 = instruction[24:20];
wire [4:0] dest_reg; assign dest_reg = instruction[11:7];
wire [31:0] read_reg1;
wire [31:0] read_reg2;
reg wb_valid;

reg [31:0] write_back_data=0;

wire [24:0] raw_imm; assign raw_imm = instruction[31:7];
wire [31:0] immediate;

wire [31:0] alu_result;
reg [31:0] alu_src2;

wire [3:0] mem_byte_enable;
wire [31:0] mem_write_data;

wire [31:0] mem_read;

wire [31:0] mem_read_write_back_data;
wire mem_read_write_back_valid;

// pc         

always @(*) begin
    case (PCSrc)
        1'b0 : pc_next = pc + 3'b100; // pc + 4
        1'b1 : pc_next = pc_plus_second_add;
		  default : pc_next = pc + 3'b100;
    endcase
	 end
always @(*) begin
    case (second_add_source)
        2'b00 : pc_plus_second_add = pc + immediate;
        2'b01 : pc_plus_second_add = immediate;
        2'b10 : pc_plus_second_add = read_reg1 + immediate;
        default : pc_plus_second_add = 32'd0;
    endcase
end



// Thanh ghi PC
PC PC(
		.clk(clk),
		.rst(rst_n),
		.pc_next(pc_next),
		.pc(pc) 
    );

instr_mem instr_mem(
    .clk(clk),
    .addr(pc_next[11:2]),                 
    .dout(instruction)
);

data_mem Mem(
	 .clk(clk),
    .rst_n(rst_n),
    .address({alu_result[31:2], 2'b00}),
    .write_data(mem_write_data),
    .byte_enable(mem_byte_enable),
    .write_enable(mem_write),
    .read_data(mem_read));	 

control Control(
	 .Op(op),.funct7(f7),
    .funct3(f3),
	 .alu_zero(alu_zero),
    .alu_last_bit(alu_last_bit), 
    .RegWrite(reg_write),
	 .ALUSrc(alu_source),
	 .MemWrite(mem_write),
	 .ResultSrc(ResultSrc),
	 .PCSrc(PCSrc),    
	 .ImmSrc(imm_source),
    .ALUControl(alu_control),
	 .SecondPC(second_add_source));	 

always @(*) begin
    case (ResultSrc)
        2'b00: begin
            write_back_data = alu_result;
            wb_valid = 1'b1;
        end
        2'b01: begin
            write_back_data = mem_read_write_back_data;
            wb_valid = mem_read_write_back_valid;
        end	 
        2'b10: begin
            write_back_data = pc + 4;
            wb_valid = 1'b1;
        end
        2'b11: begin
            write_back_data = pc_next;
            wb_valid = 1'b1;
        end
    endcase
end

always @(*) begin
    case (alu_source)
        1'b1: alu_src2 = immediate;
		  1'b0: alu_src2 = read_reg2;
        default: alu_src2 = read_reg2;
    endcase
end	 
	 
ALU alu(
	.src1(read_reg1),.src2(alu_src2),
	.alucontrol(alu_control),
	.alu_result(alu_result),
	.zero(alu_zero),
	.last_bit(alu_last_bit),
	.word_aligned(),
	.halfword_aligned());

regfile Regfile(
	.clk(clk),.we3(reg_write & wb_valid),.rst(rst_n),
	.a1(source_reg1),.a2(source_reg2),.a3(dest_reg),
	.wd3(write_back_data),
	.rd1(read_reg1),.rd2(read_reg2)
	);
	
signextend SignExt (
.instr(raw_imm),
.immsrc(imm_source),
.immext(immediate));

reader Reader(
    .mem_data(mem_read),
    .be_mask(mem_byte_enable),
    .f3(f3),

    .wb_data(mem_read_write_back_data),
    .valid(mem_read_write_back_valid));
	 
load_store_decoder load(
    .alu_result_address(alu_result),
    .f3(f3),
    .reg_read(read_reg2),
    .byte_enable(mem_byte_enable),
    .data(mem_write_data)
);



endmodule