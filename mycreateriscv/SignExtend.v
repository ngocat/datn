module signextend(
		input wire [24:0] instr,
		input wire [2:0] immsrc,
		output reg [31:0] immext
    );
 always @(*) begin
	case(immsrc)
	//i
		3'b000: immext = {{20{instr[24]}},instr[24:13]};
	//s
		3'b001: immext = {{20{instr[24]}},instr[24:18],instr[4:0]};
	//b
		3'b010: immext = {{20{instr[24]}},instr[0],instr[23:18],instr[4:1],1'b0};
	//j
		3'b011: immext = {{12{instr[24]}}, instr[12:5], instr[13], instr[23:14], 1'b0};
	//u
		3'b100: immext = {instr[24:5],12'b000000000000};
		default immext = 32'b0;
	endcase
end

endmodule