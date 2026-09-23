module instr_mem(
    input  wire        clk,
    input  wire [9:0] addr,
    output wire  [31:0] dout
);
/// using IP Bram Block
 data_mem_core instr_mem (
    .clka(clk),
	 .wea(1'b0),
	 .dina(32'd0),
    .addra(addr),                 // word aligned
    .douta(dout)
);

endmodule
