module ALU(
	input [31:0] src1,src2,
	input [3:0] alucontrol,
	output reg [31:0] alu_result,
	output zero,last_bit,
	output word_aligned,
	output halfword_aligned
    );
wire [4:0] shamt = src2[4:0];
	 always @(*) begin
		case (alucontrol)
        // ADD STUFF
        4'b0000 : alu_result = src1 + src2;
        // AND STUFF
        4'b0010 : alu_result = src1 & src2;
        // OR STUFF
        4'b0011 : alu_result = src1 | src2;
        // SUB Stuff (src1 - src2)
        4'b0001 : alu_result = src1 + (~src2 + 1'b1);
        // LESS THAN COMPARE STUFF (signed)
        4'b0101 : alu_result = {31'b0, $signed(src1) < $signed(src2)}; // co dau
        // LESS THAN COMPARE STUFF (unsigned)
        4'b0111 : alu_result = {31'b0, src1 < src2};
        // XOR STUFF
        4'b1000 : alu_result = src1 ^ src2;
        // SLL STUFF
        4'b0100 : alu_result = src1 << shamt;
        // SRL STUFF
        4'b0110 : alu_result = src1 >> shamt;
        // SRA STUFF
        4'b1001 : alu_result = $signed(src1) >>> shamt;
        default : alu_result = 32'd0;
    endcase
end
	
// determine address alignment
assign word_aligned     = (alu_result[1:0] == 2'b00);
assign halfword_aligned = (alu_result[0]   == 1'b0);

assign zero     = (alu_result == 32'b0)? 1'b1:0;
assign last_bit = alu_result[0];

endmodule