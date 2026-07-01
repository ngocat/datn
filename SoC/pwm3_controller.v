// ============================================================
// pwm3_controller.v
// PWM3 output for servo control on Tang Nano 9K pin 25.
// ============================================================

module pwm3_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pwm3_ctrl_i,
    input  wire [31:0] pwm3_prescale_i,
    input  wire [31:0] pwm3_period_i,
    input  wire [31:0] pwm3_compare_i,
    output wire [31:0] pwm3_counter_o,
    output wire        pwm3_pwm_out
);

    pwm_generator pwm_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .ctrl_i     (pwm3_ctrl_i),
        .prescale_i (pwm3_prescale_i),
        .period_i   (pwm3_period_i),
        .compare_i  (pwm3_compare_i),
        .counter_o  (pwm3_counter_o),
        .pwm_out    (pwm3_pwm_out)
    );

endmodule
