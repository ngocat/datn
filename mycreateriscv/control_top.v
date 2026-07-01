`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:18:18 09/04/2025 
// Design Name: 
// Module Name:    control 
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
module control(
	 input [6:0]Op,funct7,
     input [2:0]funct3,
	 input wire alu_zero,
     input wire alu_last_bit,
     output  RegWrite,ALUSrc,MemWrite,PCSrc,
     output [2:0]ImmSrc,
     output [3:0]ALUControl,
	 output [1:0]SecondPC,ResultSrc
	 );
	  wire [1:0]ALUOp;
	  wire Branch,Jump;
	  reg a_branch;
	main_decoder Main_Decoder(
                .opcode(Op),
					 .funct3(funct3),
                .funct7(funct7),
                .RegWrite(RegWrite),
                .ImmSrc(ImmSrc),
                .MemWrite(MemWrite),
                .ResultSrc(ResultSrc),
                .Branch(Branch),
                .ALUSrc(ALUSrc),
                .ALUOp(ALUOp),
					 .SecondPC(SecondPC),
					 .Jump(Jump)
    );
	ALU_decoder ALU_Decoder(
                            .ALUOp(ALUOp),
                            .funct3(funct3),
                            .funct7(funct7),
                            .opcode(Op),
                            .ALUControl(ALUControl)
    );
	 always @(*) begin
		case(funct3)
			3'b000:  a_branch = alu_zero & Branch;
			3'b100, 3'b110: a_branch = alu_last_bit & Branch;
			3'b001: a_branch = ~alu_zero & Branch;
			3'b101, 3'b111: a_branch = ~alu_last_bit & Branch;
		default : a_branch = 1'b0;
		endcase
end		
	 assign PCSrc = a_branch | Jump;
endmodule
