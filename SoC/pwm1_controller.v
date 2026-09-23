// ============================================================
// pwm1_controller.v
// PWM1 output for fan control on Tang Nano 9K pin 27.
// ============================================================

module pwm1_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pwm1_ctrl_i,
    input  wire [31:0] pwm1_prescale_i,
    input  wire [31:0] pwm1_period_i,
    input  wire [31:0] pwm1_compare_i,
    output wire [31:0] pwm1_counter_o,
    output wire        pwm1_pwm_out
);

    pwm_generator pwm_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .ctrl_i     (pwm1_ctrl_i),
        .prescale_i (pwm1_prescale_i),
        .period_i   (pwm1_period_i),
        .compare_i  (pwm1_compare_i),
        .counter_o  (pwm1_counter_o),
        .pwm_out    (pwm1_pwm_out)
    );

endmodule
