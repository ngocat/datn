module ALU_decoder(
	input [1:0] ALUOp ,
	input [6:0] opcode,
	input [2:0] funct3,
	input [6:0] funct7,
	output reg [3:0] ALUControl
    );
	wire RtypeSub = funct7[5] & opcode[5];
	always @(*) begin
		case (ALUOp)
			2'b00:	ALUControl = 4'b0000; // lw,sw
			2'b01:	begin
						 case(funct3)
							3'b000,3'b001: ALUControl = 4'b0001; //beq,bne
							3'b100,3'b101: ALUControl = 4'b0101; //blt,bge
							3'b110,3'b111: ALUControl = 4'b0111;	//bltu,bgeu
							default:	ALUControl = 4'b1111;
							endcase
							end
			2'b10:	begin
						 case(funct3) //math
							3'b000:	begin if (RtypeSub) 
											ALUControl = 4'b0001; // sub
										else          
											ALUControl = 4'b0000; // add, addi
										end
							3'b111:	ALUControl = 4'b0010; // and, andi
							3'b110:	ALUControl = 4'b0011; // or, ori
							3'b010:	ALUControl = 4'b0101; // slt, slti
							3'b011:	ALUControl = 4'b0111;  //sltu
							3'b100:	ALUControl = 4'b1000;	//xor
							3'b001:	ALUControl = 4'b0100;    //sll
							3'b101:	begin 		//srl,sra
											if(RtypeSub== 1'b0)
												ALUControl = 4'b0110;	//srl
											else
												ALUControl = 4'b1001; //sra
										end
							default:	ALUControl = 4'b1111; // ???	
						endcase
						end
			default:	ALUControl = 4'b1111;
		endcase
	end
endmodule
