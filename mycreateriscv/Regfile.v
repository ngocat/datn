module regfile(
	input clk,we3,rst,
	input [4:0] a1,a2,a3,
	input [31:0] wd3,
	output [31:0] rd1,rd2
    );
	 integer i;
	 reg [31:0] Register [0:31];
 // synchronous reset + write
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                Register[i] <= 32'b0;    // reset x0..x31
        end
        else if (we3 && a3 != 5'd0) begin
            Register[a3] <= wd3;        // write register except x0
        end
    end

    // read is combinational
    assign rd1 = Register[a1];
    assign rd2 = Register[a2];
endmodule