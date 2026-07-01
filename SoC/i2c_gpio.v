/* I2C GPIO bit-bang peripheral
 *
 * Memory-mapped register at base address:
 *   Write: bit[0] = SCL (1=release/high, 0=drive low)
 *          bit[1] = SDA (1=release/high, 0=drive low)
 *   Read:  bit[0] = SCL pin level
 *          bit[1] = SDA pin level
 *
 * Open-drain I2C: FPGA drives low or releases (high-Z).
 * External pull-up resistors (4.7k to 3.3V) required on SCL and SDA.
 */

module i2c_gpio (
    input wire         clk,
    input wire         reset_n,
    input wire         i2c_sel,
    input wire [31:0]  i2c_data_i,
    input wire         we,
    output wire        i2c_ready,
    output wire [31:0] i2c_data_o,
    output reg         scl_o,
    output reg         sda_o,
    input wire         scl_i,
    input wire         sda_i
);

    assign i2c_data_o = {30'b0, sda_i, scl_i};
    assign i2c_ready = i2c_sel;

    always @(posedge clk or negedge reset_n)
        if (!reset_n) begin
            scl_o <= 1'b1;
            sda_o <= 1'b1;
        end else if (i2c_sel && we) begin
            scl_o <= i2c_data_i[0];
            sda_o <= i2c_data_i[1];
        end

endmodule
