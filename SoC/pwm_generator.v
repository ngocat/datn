// ============================================================
// pwm_generator.v
// Register-style PWM core.
//
// CTRL[0] = enable
// CTRL[1] = mode, reserved for future use. 0 = edge-aligned.
// CTRL[2] = polarity. 0 = active high, 1 = active low.
// PRESCALE = number of clk cycles per PWM counter tick.
// PERIOD   = PWM counter period in ticks.
// COMPARE  = compare value. Output is active when COUNTER < COMPARE.
// COUNTER  = current counter value.
// ============================================================

module pwm_generator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] ctrl_i,
    input  wire [31:0] prescale_i,
    input  wire [31:0] period_i,
    input  wire [31:0] compare_i,
    output wire [31:0] counter_o,
    output wire        pwm_out
);

    reg [31:0] prescale_counter;
    reg [31:0] period_counter;
    reg        pwm_raw;

    wire        enable;
    wire        polarity;
    wire [31:0] prescale_limit;
    wire [31:0] period_limit;
    wire [31:0] compare_limit;

    assign enable         = ctrl_i[0];
    assign polarity       = ctrl_i[2];
    assign prescale_limit = (prescale_i < 32'd1) ? 32'd1 : prescale_i;
    assign period_limit   = (period_i   < 32'd1) ? 32'd1 : period_i;
    assign compare_limit  = (compare_i > period_limit) ? period_limit : compare_i;
    assign counter_o      = period_counter;
    assign pwm_out        = polarity ? ~pwm_raw : pwm_raw;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescale_counter <= 32'd0;
            period_counter   <= 32'd0;
        end else if (!enable) begin
            prescale_counter <= 32'd0;
            period_counter   <= 32'd0;
        end else begin
            if (prescale_counter >= (prescale_limit - 32'd1)) begin
                prescale_counter <= 32'd0;

                if (period_counter >= (period_limit - 32'd1))
                    period_counter <= 32'd0;
                else
                    period_counter <= period_counter + 32'd1;
            end else begin
                prescale_counter <= prescale_counter + 32'd1;
            end
        end
    end

    always @(*) begin
        if (!enable)
            pwm_raw = 1'b0;
        else
            pwm_raw = (period_counter < compare_limit);
    end

endmodule
