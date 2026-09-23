module gpio_reg (
	input  wire        clk,
	input  wire        reset_n,
	input  wire        gpio_sel,
	input  wire [31:0] gpio_data_i,
	input  wire        we,
	input  wire        gpio_btn31_n,
	input  wire        gpio_btn32_n,
	input  wire        gpio_btn49_n,
	input  wire        btn_s2,
	output wire        gpio_ready,
	output wire [31:0] gpio_data_o
);

	reg [31:0] gpio_value;

	assign gpio_ready = gpio_sel;
	assign gpio_data_o = {29'b0, ~btn_s2, ~gpio_btn49_n, ~gpio_btn32_n, ~gpio_btn31_n};

	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			gpio_value <= 32'b0;
		end else if (gpio_sel && we) begin
			gpio_value <= gpio_data_i;
		end
	end

endmodule