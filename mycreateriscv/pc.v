module PC(
		input clk,rst,
		input [31:0] pc_next,
		output reg [31:0] pc 
    );
	always @(posedge clk) begin
		 if (rst) begin
			  pc <= 32'b0;
			  end
		 else begin
			  pc <= pc_next;   // synch
			  end
	end
endmodule
