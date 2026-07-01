// ============================================================
// pwm2_controller.v
// PWM2 output for servo control on Tang Nano 9K pin 26.
// ============================================================

module pwm2_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pwm2_ctrl_i,
    input  wire [31:0] pwm2_prescale_i,
    input  wire [31:0] pwm2_period_i,
    input  wire [31:0] pwm2_compare_i,
    output wire [31:0] pwm2_counter_o,
    output wire        pwm2_pwm_out
);

    pwm_generator pwm_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .ctrl_i     (pwm2_ctrl_i),
        .prescale_i (pwm2_prescale_i),
        .period_i   (pwm2_period_i),
        .compare_i  (pwm2_compare_i),
        .counter_o  (pwm2_counter_o),
        .pwm_out    (pwm2_pwm_out)
    );

endmodule
