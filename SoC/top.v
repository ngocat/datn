
module top (
            input wire        clk,
            input wire        reset_button_n,
            input wire        gpio_btn31_n,
            input wire        gpio_btn32_n,
            input wire        gpio_btn49_n,
            input wire        btn_s2,
            input wire        uart_rx,
            output wire       uart_tx,

            inout wire        i2c_scl,
            inout wire        i2c_sda,
            inout wire        i2c2_scl,
            inout wire        i2c2_sda,
            inout wire        i2c3_scl,
            inout wire        i2c3_sda,
            output wire [5:0] leds,
            output wire       fan_pwm,    // Chân 27 — D4184 PWM (quạt)
            output wire       servo_pwm,  // Chân 26 — SG90 Servo PWM
            output wire       servo_pwm2  // Chân 25 — SG90 Servo PWM 2
            );

   parameter [0:0] BARREL_SHIFTER = 0;
   parameter [0:0] ENABLE_MUL = 0;
   parameter [0:0] ENABLE_DIV = 0;
   parameter [0:0] ENABLE_FAST_MUL = 0;
   parameter [0:0] ENABLE_COMPRESSED = 0;
   parameter [0:0] ENABLE_IRQ_QREGS = 0;

   parameter integer          MEMBYTES = 8192;      // This is not easy to change
   parameter [31:0] STACKADDR = (MEMBYTES);         // Grows down.  Software should set it.
   parameter [31:0] PROGADDR_RESET = 32'h0000_0000;
   parameter [31:0] PROGADDR_IRQ = 32'h0000_0000;

   wire                       reset_n; 
   wire [31:0]                mem_addr;
   wire [31:0]                mem_wdata;
   wire [31:0]                mem_rdata;
   wire [3:0]                 mem_wstrb;
   wire                       mem_valid;
   wire                       mem_ready;
   wire                       mem_instr;
   wire                       leds_sel;
   wire                       leds_ready;
   wire [31:0]                leds_data_o;
   wire                       sram_sel;
   wire                       sram_ready;
   wire [31:0]                sram_data_o;
   wire                       cdt_sel;
   wire                       cdt_ready;
   wire [31:0]                cdt_data_o;
   wire                       uart_sel;
   wire [31:0]                uart_data_o;
   wire                       uart_ready;
   wire                       i2c_sel;
   wire                       i2c_ready;
   wire [31:0]                i2c_data_o;
   wire                       i2c_scl_o;
   wire                       i2c_sda_o;
   wire                       i2c2_sel;
   wire                       i2c2_ready;
   wire [31:0]                i2c2_data_o;
   wire                       i2c2_scl_o;
   wire                       i2c2_sda_o;
   wire                       i2c3_sel;
   wire                       i2c3_ready;
   wire [31:0]                i2c3_data_o;
   wire                       i2c3_scl_o;
   wire                       i2c3_sda_o;
  wire                        gpio_sel;
  wire                        gpio_ready;
  wire [31:0]                 gpio_data_o;
  wire                        user_gpio_ready;
  wire [31:0]                 user_gpio_data_o;
  wire                       pwm_sel;
  wire [31:0]                pwm1_ctrl;
  wire [31:0]                pwm1_prescale;
  wire [31:0]                pwm1_period;
  wire [31:0]                pwm1_compare;
  wire [31:0]                pwm1_counter;
  wire [31:0]                pwm2_ctrl;
  wire [31:0]                pwm2_prescale;
  wire [31:0]                pwm2_period;
  wire [31:0]                pwm2_compare;
  wire [31:0]                pwm2_counter;
  wire [31:0]                pwm3_ctrl;
  wire [31:0]                pwm3_prescale;
  wire [31:0]                pwm3_period;
  wire [31:0]                pwm3_compare;
  wire [31:0]                pwm3_counter;


   // I2C open-drain tristate: release (high-Z) when output is 1, drive low when 0
   assign i2c_scl  = i2c_scl_o  ? 1'bz : 1'b0;
   assign i2c_sda  = i2c_sda_o  ? 1'bz : 1'b0;
   assign i2c2_scl = i2c2_scl_o ? 1'bz : 1'b0;
   assign i2c2_sda = i2c2_sda_o ? 1'bz : 1'b0;
   assign i2c3_scl = i2c3_scl_o ? 1'bz : 1'b0;
   assign i2c3_sda = i2c3_sda_o ? 1'bz : 1'b0;

   // Establish memory map for all slaves:
   //   SRAM 00000000 - 0001ffff
   //   LED  80000000
   //   UART 80000008 - 8000000f
   //   CDT  80000010 - 80000014
   //   I2C  80000020
   //   I2C2 80000024
   //   PWM1/PWM2/PWM3 register block 80000028 - 80000064
   //   GPIO 80000068
   //   I2C3 8000006c
   // Memory map:
   //   SRAM     00000000 - 00001fff
   //   LED      80000000
   //   UART     80000008 - 8000000f
   //   CDT      80000010 - 80000014
   //   I2C      80000020
   //   I2C2     80000024
  //   PWM1_CTRL     80000028
  //   PWM1_PRESCALE 8000002C
  //   PWM1_PERIOD   80000030
  //   PWM1_COMPARE  80000034
  //   PWM1_COUNTER  80000038
  //   PWM2_CTRL     8000003C
  //   PWM2_PRESCALE 80000040
  //   PWM2_PERIOD   80000044
  //   PWM2_COMPARE  80000048
  //   PWM2_COUNTER  8000004C
  //   PWM3_CTRL     80000050
  //   PWM3_PRESCALE 80000054
  //   PWM3_PERIOD   80000058
  //   PWM3_COMPARE  8000005C
  //   PWM3_COUNTER  80000060
  //   GPIO          80000068
  //   I2C3          8000006C
   assign sram_sel  = mem_valid && (mem_addr < 32'h00002000);
   assign leds_sel  = mem_valid && (mem_addr == 32'h80000000);
   assign uart_sel  = mem_valid && ((mem_addr & 32'hfffffff8) == 32'h80000008);
   assign cdt_sel   = mem_valid && (mem_addr == 32'h80000010);
   assign i2c_sel   = mem_valid && (mem_addr == 32'h80000020);
   assign i2c2_sel  = mem_valid && (mem_addr == 32'h80000024);
   assign i2c3_sel  = mem_valid && (mem_addr == 32'h8000006c);
  assign pwm_sel   = mem_valid && (mem_addr >= 32'h80000028) && (mem_addr <= 32'h80000064);
  assign gpio_sel  = mem_valid && (mem_addr == 32'h80000068);

  // Core can proceed regardless of *which* slave was targetted and is now ready.
  assign mem_ready = mem_valid & (sram_ready | leds_ready | uart_ready | cdt_ready | i2c_ready | i2c2_ready | i2c3_ready | gpio_ready | user_gpio_ready);


  // Select which slave's output data is to be fed to core.
  assign mem_rdata = sram_sel  ? sram_data_o  :
                      leds_sel  ? leds_data_o  :
                      uart_sel  ? uart_data_o  :
                      cdt_sel   ? cdt_data_o   :
                      i2c_sel   ? i2c_data_o   :
                      i2c2_sel  ? i2c2_data_o  :
                      i2c3_sel  ? i2c3_data_o  :
                      gpio_sel ? user_gpio_data_o :
                      pwm_sel ? gpio_data_o :
                                  32'h0;

  assign leds = ~leds_data_o[5:0]; // Connect to the LEDs off the FPGA

  reset_control reset_controller
     (
      .clk(clk),
      .reset_button_n(reset_button_n),
      .reset_n(reset_n)
      );

  uart_wrap uart
     (
      .clk(clk),
      .reset_n(reset_n),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),
      .uart_sel(uart_sel),
      .addr(mem_addr[3:0]),
      .uart_wstrb(mem_wstrb),
      .uart_di(mem_wdata),
      .uart_do(uart_data_o),
      .uart_ready(uart_ready)
      );

  countdown_timer cdt
     (
      .clk(clk),
      .reset_n(reset_n),
      .cdt_sel(cdt_sel),
      .cdt_data_i(mem_wdata),
      .we(mem_wstrb),
      .cdt_ready(cdt_ready),
      .cdt_data_o(cdt_data_o)
      );

  sram #(.ADDRWIDTH(13)) memory
     (
      .clk(clk),
      .resetn(reset_n),
      .sram_sel(sram_sel),
      .wstrb(mem_wstrb),
      .addr(mem_addr[12:0]),
      .sram_data_i(mem_wdata),
      .sram_ready(sram_ready),
      .sram_data_o(sram_data_o)
      );
   
  tang_leds soc_leds
     (
      .clk(clk),
      .reset_n(reset_n),
      .leds_sel(leds_sel),
      .leds_data_i(mem_wdata[5:0]),
      .we(mem_wstrb[0]),
      .leds_ready(leds_ready),
      .leds_data_o(leds_data_o)
      );

  i2c_gpio i2c
     (
      .clk(clk),
      .reset_n(reset_n),
      .i2c_sel(i2c_sel),
      .i2c_data_i(mem_wdata),
      .we(mem_wstrb[0]),
      .i2c_ready(i2c_ready),
      .i2c_data_o(i2c_data_o),
      .scl_o(i2c_scl_o),
      .sda_o(i2c_sda_o),
      .scl_i(i2c_scl),
      .sda_i(i2c_sda)
      );

  i2c_gpio i2c2
     (
      .clk(clk),
      .reset_n(reset_n),
      .i2c_sel(i2c2_sel),
      .i2c_data_i(mem_wdata),
      .we(mem_wstrb[0]),
      .i2c_ready(i2c2_ready),
      .i2c_data_o(i2c2_data_o),
      .scl_o(i2c2_scl_o),
      .sda_o(i2c2_sda_o),
      .scl_i(i2c2_scl),
      .sda_i(i2c2_sda)
      );

  i2c_gpio i2c3
     (
      .clk(clk),
      .reset_n(reset_n),
      .i2c_sel(i2c3_sel),
      .i2c_data_i(mem_wdata),
      .we(mem_wstrb[0]),
      .i2c_ready(i2c3_ready),
      .i2c_data_o(i2c3_data_o),
      .scl_o(i2c3_scl_o),
      .sda_o(i2c3_sda_o),
      .scl_i(i2c3_scl),
      .sda_i(i2c3_sda)
      );

  gpio_reg user_gpio
     (
      .clk(clk),
      .reset_n(reset_n),
      .gpio_sel(gpio_sel),
      .gpio_data_i(mem_wdata),
      .we(mem_wstrb[0]),
      .gpio_btn31_n(gpio_btn31_n),
      .gpio_btn32_n(gpio_btn32_n),
      .gpio_btn49_n(gpio_btn49_n),
      .btn_s2(btn_s2),
      .gpio_ready(user_gpio_ready),
      .gpio_data_o(user_gpio_data_o)
      );


  // ---- PWM register block + controllers ----
  pwm_gpio_reg pwm_gpio (
       .clk              (clk),
       .rst_n            (reset_n),
       .pwm_sel          (pwm_sel),
       .addr_i           (mem_addr),
       .data_i           (mem_wdata),
       .we               (mem_wstrb),
       .pwm1_counter_i   (pwm1_counter),
       .pwm2_counter_i   (pwm2_counter),
       .pwm3_counter_i   (pwm3_counter),
       .ready_o          (gpio_ready),
       .data_o           (gpio_data_o),
       .pwm1_ctrl_o      (pwm1_ctrl),
       .pwm1_prescale_o  (pwm1_prescale),
       .pwm1_period_o    (pwm1_period),
       .pwm1_compare_o   (pwm1_compare),
       .pwm2_ctrl_o      (pwm2_ctrl),
       .pwm2_prescale_o  (pwm2_prescale),
       .pwm2_period_o    (pwm2_period),
       .pwm2_compare_o   (pwm2_compare),
       .pwm3_ctrl_o      (pwm3_ctrl),
       .pwm3_prescale_o  (pwm3_prescale),
       .pwm3_period_o    (pwm3_period),
       .pwm3_compare_o   (pwm3_compare)
   );

  pwm1_controller pwm1_controller_inst (
       .clk              (clk),
       .rst_n            (reset_n),
       .pwm1_ctrl_i      (pwm1_ctrl),
       .pwm1_prescale_i  (pwm1_prescale),
       .pwm1_period_i    (pwm1_period),
       .pwm1_compare_i   (pwm1_compare),
       .pwm1_counter_o   (pwm1_counter),
       .pwm1_pwm_out     (fan_pwm)
  );

  pwm2_controller pwm2_controller_inst (
       .clk              (clk),
       .rst_n            (reset_n),
       .pwm2_ctrl_i      (pwm2_ctrl),
       .pwm2_prescale_i  (pwm2_prescale),
       .pwm2_period_i    (pwm2_period),
       .pwm2_compare_i   (pwm2_compare),
       .pwm2_counter_o   (pwm2_counter),
       .pwm2_pwm_out     (servo_pwm)
  );

  pwm3_controller pwm3_controller_inst (
       .clk              (clk),
       .rst_n            (reset_n),
       .pwm3_ctrl_i      (pwm3_ctrl),
       .pwm3_prescale_i  (pwm3_prescale),
       .pwm3_period_i    (pwm3_period),
       .pwm3_compare_i   (pwm3_compare),
       .pwm3_counter_o   (pwm3_counter),
       .pwm3_pwm_out     (servo_pwm2)
  );

  rv32i_bus
     #(
       .STACKADDR(STACKADDR),
       .PROGADDR_RESET(PROGADDR_RESET),
       .PROGADDR_IRQ(PROGADDR_IRQ),
       .BARREL_SHIFTER(BARREL_SHIFTER),
       .COMPRESSED_ISA(ENABLE_COMPRESSED),
       .ENABLE_MUL(ENABLE_MUL),
       .ENABLE_DIV(ENABLE_DIV),
       .ENABLE_FAST_MUL(ENABLE_FAST_MUL),
       .ENABLE_IRQ(1),
       .ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
      ) cpu
      (
        .clk         (clk),
        .resetn      (reset_n),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .irq         ('b0)
  );

endmodule 
