// ============================================================
// pwm_gpio_reg.v
// Register block for three commercial-style PWM channels.
//
// PWM1 base 0x80000028:
//   +0x00 CTRL      RW: bit0 enable, bit1 mode, bit2 polarity
//   +0x04 PRESCALE  RW: clock cycles per PWM counter tick
//   +0x08 PERIOD    RW: PWM period in counter ticks
//   +0x0C COMPARE   RW: compare/duty threshold
//   +0x10 COUNTER   RO: current counter value
//
// PWM2 base 0x8000003C:
//   +0x00 CTRL      RW
//   +0x04 PRESCALE  RW
//   +0x08 PERIOD    RW
//   +0x0C COMPARE   RW
//   +0x10 COUNTER   RO
//
// PWM3 base 0x80000050:
//   +0x00 CTRL      RW
//   +0x04 PRESCALE  RW
//   +0x08 PERIOD    RW
//   +0x0C COMPARE   RW
//   +0x10 COUNTER   RO
// ============================================================

module pwm_gpio_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pwm_sel,
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    input  wire [3:0]  we,
    input  wire [31:0] pwm1_counter_i,
    input  wire [31:0] pwm2_counter_i,
    input  wire [31:0] pwm3_counter_i,
    output wire        ready_o,
    output reg  [31:0] data_o,
    output wire [31:0] pwm1_ctrl_o,
    output wire [31:0] pwm1_prescale_o,
    output wire [31:0] pwm1_period_o,
    output wire [31:0] pwm1_compare_o,
    output wire [31:0] pwm2_ctrl_o,
    output wire [31:0] pwm2_prescale_o,
    output wire [31:0] pwm2_period_o,
    output wire [31:0] pwm2_compare_o,
    output wire [31:0] pwm3_ctrl_o,
    output wire [31:0] pwm3_prescale_o,
    output wire [31:0] pwm3_period_o,
    output wire [31:0] pwm3_compare_o
);

    localparam [31:0] PWM1_BASE = 32'h80000028;
    localparam [31:0] PWM2_BASE = 32'h8000003C;
    localparam [31:0] PWM3_BASE = 32'h80000050;

    localparam [31:0] PWM_CTRL_RESET     = 32'h00000001;
    localparam [31:0] PWM1_PERIOD_RESET  = 32'd1000;
    localparam [31:0] PWM1_COMPARE_RESET = 32'd0;
    localparam [31:0] PWM2_PERIOD_RESET  = 32'd20000;
    localparam [31:0] PWM2_COMPARE_RESET = 32'd1500;
    localparam [31:0] PWM3_PERIOD_RESET  = 32'd20000;
    localparam [31:0] PWM3_COMPARE_RESET = 32'd1500;
    localparam [31:0] PWM_PRESCALE_RESET = 32'd27;

    reg [31:0] reg_pwm1_ctrl;
    reg [31:0] reg_pwm1_prescale;
    reg [31:0] reg_pwm1_period;
    reg [31:0] reg_pwm1_compare;
    reg [31:0] reg_pwm2_ctrl;
    reg [31:0] reg_pwm2_prescale;
    reg [31:0] reg_pwm2_period;
    reg [31:0] reg_pwm2_compare;
    reg [31:0] reg_pwm3_ctrl;
    reg [31:0] reg_pwm3_prescale;
    reg [31:0] reg_pwm3_period;
    reg [31:0] reg_pwm3_compare;

    wire write_en;

    assign ready_o          = pwm_sel;
    assign write_en         = pwm_sel && (we != 4'b0000);
    assign pwm1_ctrl_o      = reg_pwm1_ctrl;
    assign pwm1_prescale_o  = reg_pwm1_prescale;
    assign pwm1_period_o    = reg_pwm1_period;
    assign pwm1_compare_o   = reg_pwm1_compare;
    assign pwm2_ctrl_o      = reg_pwm2_ctrl;
    assign pwm2_prescale_o  = reg_pwm2_prescale;
    assign pwm2_period_o    = reg_pwm2_period;
    assign pwm2_compare_o   = reg_pwm2_compare;
    assign pwm3_ctrl_o      = reg_pwm3_ctrl;
    assign pwm3_prescale_o  = reg_pwm3_prescale;
    assign pwm3_period_o    = reg_pwm3_period;
    assign pwm3_compare_o   = reg_pwm3_compare;

    always @(*) begin
        case (addr_i)
            PWM1_BASE + 32'h00: data_o = reg_pwm1_ctrl;
            PWM1_BASE + 32'h04: data_o = reg_pwm1_prescale;
            PWM1_BASE + 32'h08: data_o = reg_pwm1_period;
            PWM1_BASE + 32'h0C: data_o = reg_pwm1_compare;
            PWM1_BASE + 32'h10: data_o = pwm1_counter_i;
            PWM2_BASE + 32'h00: data_o = reg_pwm2_ctrl;
            PWM3_BASE + 32'h00: data_o = reg_pwm3_ctrl;
            PWM3_BASE + 32'h04: data_o = reg_pwm3_prescale;
            PWM3_BASE + 32'h08: data_o = reg_pwm3_period;
            PWM3_BASE + 32'h0C: data_o = reg_pwm3_compare;
            PWM3_BASE + 32'h10: data_o = pwm3_counter_i;
            PWM2_BASE + 32'h04: data_o = reg_pwm2_prescale;
            PWM2_BASE + 32'h08: data_o = reg_pwm2_period;
            PWM2_BASE + 32'h0C: data_o = reg_pwm2_compare;
            PWM2_BASE + 32'h10: data_o = pwm2_counter_i;
            default:           data_o = 32'h0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_pwm1_ctrl     <= PWM_CTRL_RESET;
            reg_pwm1_prescale <= PWM_PRESCALE_RESET;
            reg_pwm1_period   <= PWM1_PERIOD_RESET;
            reg_pwm1_compare  <= PWM1_COMPARE_RESET;
            reg_pwm2_ctrl     <= PWM_CTRL_RESET;
            reg_pwm2_prescale <= PWM_PRESCALE_RESET;
            reg_pwm2_period   <= PWM2_PERIOD_RESET;
            reg_pwm2_compare  <= PWM2_COMPARE_RESET;
            reg_pwm3_ctrl     <= PWM_CTRL_RESET;
            reg_pwm3_prescale <= PWM_PRESCALE_RESET;
            reg_pwm3_period   <= PWM3_PERIOD_RESET;
            reg_pwm3_compare  <= PWM3_COMPARE_RESET;
        end else if (write_en) begin
            case (addr_i)
                PWM1_BASE + 32'h00: reg_pwm1_ctrl     <= data_i;
                PWM1_BASE + 32'h04: reg_pwm1_prescale <= data_i;
                PWM1_BASE + 32'h08: reg_pwm1_period   <= data_i;
                PWM1_BASE + 32'h0C: reg_pwm1_compare  <= data_i;
                PWM2_BASE + 32'h00: reg_pwm2_ctrl     <= data_i;
                PWM2_BASE + 32'h04: reg_pwm2_prescale <= data_i;
                PWM2_BASE + 32'h08: reg_pwm2_period   <= data_i;
                PWM2_BASE + 32'h0C: reg_pwm2_compare  <= data_i;
                PWM3_BASE + 32'h00: reg_pwm3_ctrl     <= data_i;
                PWM3_BASE + 32'h04: reg_pwm3_prescale <= data_i;
                PWM3_BASE + 32'h08: reg_pwm3_period   <= data_i;
                PWM3_BASE + 32'h0C: reg_pwm3_compare  <= data_i;
                default: ;
            endcase
        end
    end

endmodule
