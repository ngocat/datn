#include "leds.h"
#include "i2c.h"
#include "i2c2.h"
#include "i2c3.h"
#include "ssd1309.h"
#include "aht20.h"
#include "aht20_b2.h"
#include "aht20_b3.h"
#include "gpio.h"
#include "fan.h"
#include "servo.h"
#include "servo2.h"

#define AHT20_ADDR_1 0x38
#define AHT20_ADDR_2 0x38
#define AHT20_ADDR_3 0x38

static const unsigned short servo_high_levels[3] = { 1333, 1500, 1100 };
static const unsigned short fan_high_levels[4]   = { 0, 500, 1000, 2000 };
static const unsigned short fan_period_us         = 2000;
static const unsigned short servo_period_us       = 20000;

/* ------------------------------------------------------------------ */
/*  Math helpers                                                        */
/* ------------------------------------------------------------------ */
static int my_div10(int val)
{
    int neg = 0, result = 0;
    if (val < 0) { neg = 1; val = -val; }
    while (val >= 10) { val -= 10; result++; }
    return neg ? -result : result;
}

static int my_mod10(int val)
{
    if (val < 0) val = -val;
    while (val >= 10) val -= 10;
    return val;
}

static int int_to_str(int val, char *buf)
{
    int i = 0, j, len, d, q;
    char tmp;
    int neg = 0;

    if (val < 0) { neg = 1; val = -val; }
    if (val == 0) { buf[0] = '0'; buf[1] = '\0'; return 1; }

    while (val > 0) {
        d = val;
        while (d >= 10) d -= 10;
        buf[i++] = '0' + d;
        val = val - d;
        q = 0;
        while (val >= 10) { val -= 10; q++; }
        val = q;
    }

    if (neg) buf[i++] = '-';
    buf[i] = '\0';
    len = i;

    for (j = 0; j < (i >> 1); j++) {
        tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }
    return len;
}

/* ------------------------------------------------------------------ */
/*  Display helpers                                                     */
/* ------------------------------------------------------------------ */

static void display_sensor_line(int page, int sensor_idx, int ok,
    int temp_x10, int hum_x10)
{
char buf[16];
int whole, frac;
const char *label;
if      (sensor_idx == 0) label = "Trong:";
else if (sensor_idx == 1) label = "Kinh :";
else                      label = "Ngoai:";

ssd1309_set_cursor(page, 0);
ssd1309_write_string(label);

if (ok != 0) { ssd1309_write_string("Err!"); return; }

ssd1309_set_cursor(page, 50);
whole = my_div10(temp_x10); frac = my_mod10(temp_x10);
int_to_str(whole, buf); ssd1309_write_string(buf);
ssd1309_write_char('.'); int_to_str(frac, buf); ssd1309_write_string(buf);
ssd1309_write_char(CHAR_DEGREE); ssd1309_write_char('C');
ssd1309_write_char(' ');

whole = my_div10(hum_x10); frac = my_mod10(hum_x10);
int_to_str(whole, buf); ssd1309_write_string(buf);
ssd1309_write_char('.'); int_to_str(frac, buf); ssd1309_write_string(buf);
ssd1309_write_char('%');
}

/*
 * In "DPT=XX.X°C" bắt đầu col 0.
 * Tổng tối đa: "DPT=" + "-" + "XX" + "." + "X" + "°C" + " " = ~11 ký tự = 66px
 * Không tràn sang col 62 (nơi đặt "|dT=").
 */
 static void display_dew_delta(int page, int dew_x10, int delta_x10)
 {
     char buf[16];
     int whole, frac;
 
     /* DPT= */
     ssd1309_set_cursor(page, 0);
     ssd1309_write_string("DPT=");
     if (dew_x10 < 0) { ssd1309_write_char('-'); dew_x10 = -dew_x10; }
     whole = my_div10(dew_x10); frac = my_mod10(dew_x10);
     int_to_str(whole, buf); ssd1309_write_string(buf);
     ssd1309_write_char('.'); int_to_str(frac, buf); ssd1309_write_string(buf);
     ssd1309_write_char(CHAR_DEGREE); ssd1309_write_char('C');
 
     /* dT= */
     ssd1309_set_cursor(page, 70);
     ssd1309_write_string("dT=");
     if (delta_x10 < 0) { ssd1309_write_char('-'); delta_x10 = -delta_x10; }
     whole = my_div10(delta_x10); frac = my_mod10(delta_x10);
     int_to_str(whole, buf); ssd1309_write_string(buf);
     ssd1309_write_char('.'); int_to_str(frac, buf); ssd1309_write_string(buf);
     ssd1309_write_char(CHAR_DEGREE); ssd1309_write_char('C');
 }


/* ------------------------------------------------------------------ */
/*  main                                                                */
/* ------------------------------------------------------------------ */
int main()
{
    int temp1, hum1, temp2, hum2, temp3, hum3;
    int ok1, ok2, ok3;

    unsigned char fan_level        = 1;
    unsigned char servo_level      = 1;
    unsigned char servo2_level     = 1;
    unsigned char fan_level_manual   = 1;
    unsigned char servo_level_manual  = 1;
    unsigned char servo2_level_manual = 1;

    unsigned int  gpio_state      = 0;
    unsigned int  prev_gpio_state = 0;
    unsigned char s2_mode         = 0;
    unsigned char is_manual_mode  = 0;  /* 0=AUTO FSM, 1=MANUAL override */


    /* Debounce: đợi nút THẢ RA hoàn toàn trước khi nhận nhấn mới */
    unsigned char key31_armed = 1;  /* 1 = sẵn sàng nhận nhấn */
    unsigned char key32_armed = 1;
    unsigned char key49_armed = 1;
    unsigned char keyS2_armed = 1;

        // Thêm các biến đếm thời gian nhấn giữ (đặt bên ngoài hoặc trước khi vào while(1))
    unsigned int timer_31 = 0;
    unsigned int timer_32 = 0;
    unsigned int timer_49 = 0;

    // Ngưỡng thời gian nhấn giữ. Bạn sẽ cần điều chỉnh con số này cho vừa vặn (ví dụ: 50, 100, 200...)
    #define LONG_PRESS_THRESHOLD  16

    /* --- Init hardware --- */
    set_leds(0x01);
    set_gpio(0x00000001);

    i2c_init();
    i2c2_init();
    i2c3_init();
    ssd1309_init();
    ssd1309_clear();

    aht20_init(AHT20_ADDR_1);
    aht20_init_b2(AHT20_ADDR_2);
    aht20_init_b3(AHT20_ADDR_3);

    fan_set_period_us(fan_period_us);
    fan_set_high_us(fan_high_levels[fan_level]);
    fan_enable();

    servo_set_period_us(servo_period_us);
    servo_set_high_us(servo_high_levels[servo_level]);
    servo_enable();

    servo2_set_period_us(servo_period_us);
    servo2_set_high_us(servo_high_levels[servo2_level]);
    servo2_enable();

    /* --- Màn hình khởi động --- */
    set_leds(0x07);
    ssd1309_set_cursor(0, 45);
    ssd1309_write_string("MONITOR");

    /* ---------------------------------------------------------------- */
    /*  Main loop                                                        */
    /* ---------------------------------------------------------------- */
    while (1) {

        /* ---- Đọc GPIO ---- */
        gpio_state = get_gpio();

        /* Rising-edge detection cho từng nút */
        unsigned char rising_31 = (gpio_state & 0x1u) && !(prev_gpio_state & 0x1u);
        unsigned char rising_32 = (gpio_state & 0x2u) && !(prev_gpio_state & 0x2u);
        unsigned char rising_49 = (gpio_state & 0x4u) && !(prev_gpio_state & 0x4u);
        unsigned char rising_S2 = (gpio_state & 0x8u) && !(prev_gpio_state & 0x8u);

        /* ================== NÚT 31 ================== */
        if (rising_31 && key31_armed) {

            if (is_manual_mode == 0) {
                fan_level_manual    = fan_level;    // fan_level hiện tại của Auto
                servo_level_manual  = servo_level;  // servo_level hiện tại của Auto
                servo2_level_manual = servo2_level; // servo2_level hiện tại của Auto
                is_manual_mode = 1;
            }

            fan_level_manual++;
            if (fan_level_manual >= 4) fan_level_manual = 0;
            key31_armed = 0;
            timer_31 = 0; // Reset bộ đếm khi mới bắt đầu nhấn
        }
        // Xử lý nhấn giữ nút 31
        if ((gpio_state & 0x1u) && is_manual_mode) { 
            timer_31++;
            if (timer_31 >= LONG_PRESS_THRESHOLD) {
                is_manual_mode = 0; // Chuyển ngay về AUTO
                timer_31 = 0;       // Reset bộ đếm để không bị lặp lại
            }
        } else {
            timer_31 = 0; // Thả nút ra thì reset bộ đếm về 0
        }

        /* ================== NÚT 32 ================== */
        if (rising_32 && key32_armed) {

            if (is_manual_mode == 0) {
                fan_level_manual    = fan_level;    // fan_level hiện tại của Auto
                servo_level_manual  = servo_level;  // servo_level hiện tại của Auto
                servo2_level_manual = servo2_level; // servo2_level hiện tại của Auto
                is_manual_mode = 1;
            }

            servo_level_manual++;
            if (servo_level_manual >= 3) servo_level_manual = 0;

            key32_armed = 0;
            timer_32 = 0; // Reset bộ đếm
        }
        // Xử lý nhấn giữ nút 32
        if ((gpio_state & 0x2u) && is_manual_mode) {
            timer_32++;
            if (timer_32 >= LONG_PRESS_THRESHOLD) {
                is_manual_mode = 0; // Chuyển ngay về AUTO
                timer_32 = 0;
            }
        } else {
            timer_32 = 0;
        }

        /* ================== NÚT 49 ================== */
        if (rising_49 && key49_armed) {

            if (is_manual_mode == 0) {
                fan_level_manual    = fan_level;    // fan_level hiện tại của Auto
                servo_level_manual  = servo_level;  // servo_level hiện tại của Auto
                servo2_level_manual = servo2_level; // servo2_level hiện tại của Auto
                is_manual_mode = 1;
            }

            servo2_level_manual++;
            if (servo2_level_manual >= 3) servo2_level_manual = 0;

            key49_armed = 0;
            timer_49 = 0; // Reset bộ đếm
        }
        // Xử lý nhấn giữ nút 49
        if ((gpio_state & 0x4u) && is_manual_mode) {
            timer_49++;
            if (timer_49 >= LONG_PRESS_THRESHOLD) {
                is_manual_mode = 0; // Chuyển ngay về AUTO
                timer_49 = 0;
            }
        } else {
            timer_49 = 0;
        }

        /* S2: chuyển bộ dữ liệu mô phỏng */
        if (rising_S2 && keyS2_armed) {
            s2_mode++;
            if (s2_mode >= 8) s2_mode = 0;
            //if (s2_mode == 7) is_manual_mode = 0;
            keyS2_armed = 0;
        }
                /* Debounce: re-arm khi nút đã thả hoàn toàn */
        if (!(gpio_state & 0x1u)) key31_armed = 1;
        if (!(gpio_state & 0x2u)) key32_armed = 1;
        if (!(gpio_state & 0x4u)) key49_armed = 1;
        if (!(gpio_state & 0x8u)) keyS2_armed = 1;

        prev_gpio_state = gpio_state;

        /* ---- Đọc cảm biến ---- */
        ok1 = aht20_read(AHT20_ADDR_1,    &temp1, &hum1);
        ok2 = aht20_read_b2(AHT20_ADDR_2, &temp2, &hum2);
        ok3 = aht20_read_b3(AHT20_ADDR_3, &temp3, &hum3);

        /* ---- Override data theo s2_mode (test) ---- */
        int display_temp1 = temp1, display_hum1 = hum1;
        int display_temp2 = temp2, display_hum2 = hum2;
        int display_temp3 = temp3, display_hum3 = hum3;

        if (s2_mode == 1) {
            /* KB1: Thời tiết đẹp - delta=80 */
            display_temp1 = 250; display_hum1 = 550;
            display_temp2 = 240; display_hum2 = 550;
            display_temp3 = 250; display_hum3 = 550;
        } else if (s2_mode == 2) {
            /* KB3: Cảnh báo sớm - delta=30 */
            display_temp1 = 240; display_hum1 = 700;
            display_temp2 = 210; display_hum2 = 600;
            display_temp3 = 240; display_hum3 = 700;

        } else if (s2_mode == 3) {
            /* KB2: Mờ kính nặng - delta=-20 */
            display_temp1 = 240; display_hum1 = 850;
            display_temp2 = 190; display_hum2 = 600;
            display_temp3 = 240; display_hum3 = 850;
        } else if (s2_mode == 4) {
            /* KB5: Ngoài trời mát - delta=90 */
            display_temp1 = 240; display_hum1 = 550;
            display_temp2 = 240; display_hum2 = 550;
            display_temp3 = 220; display_hum3 = 550;
        } else if (s2_mode == 5) {
            /* KB6: Nắng nóng gay gắt - delta=120 */
            display_temp1 = 250; display_hum1 = 500;
            display_temp2 = 260; display_hum2 = 500;
            display_temp3 = 380; display_hum3 = 500;
        } else if (s2_mode == 6) {
            /* KB8: Mưa lạnh xả ẩm - delta=-20 */
            display_temp1 = 230; display_hum1 = 850;
            display_temp2 = 180; display_hum2 = 600;
            display_temp3 = 160; display_hum3 = 600;
        }

        /* ---- Tính dew point & delta (đơn vị x10) ---- */
        int dew   = display_temp1 - my_div10((1000 - display_hum1) * 2);
        int delta = display_temp2 - dew;

        /* ---- Hiển thị sensor lines ---- */
        display_sensor_line(1, 0, ok1, display_temp1, display_hum1);
        display_sensor_line(2, 1, ok2, display_temp2, display_hum2);
        display_sensor_line(3, 2, ok3, display_temp3, display_hum3);

        /* ---- Hiển thị DPT và dT ---- */
        display_dew_delta(4, dew, delta);

        /* ---- Tính status string cho page 6 & 7 ---- */
        const char *status_str;
        unsigned char fan_lv_out = 1, srv1_lv_out = 1, srv2_lv_out = 1;

        /* AUTO: FSM chỉ chạy khi is_manual_mode = 0 */
        if (!is_manual_mode) {
            /* P1: Ngoài trời mát hơn bên trong (temp3 < temp1) */
            if (display_temp3 < display_temp1) {
                status_str = "NGOAI MAT ";
                fan_lv_out  = 1;   /* L1  */
                srv1_lv_out = 1;   /* OFF */
                srv2_lv_out = 2;   /* MAX */
            }
            /* P2: Nhiệt độ quá cao (temp1 > 40°C) */
            else if (display_temp1 > 370) {
                status_str = "NANG NONG ";
                fan_lv_out  = 2;   /* L2  */
                srv1_lv_out = 1;   /* OFF */
                srv2_lv_out = 1;   /* OFF */
            }
            /* P3: Mờ kính nặng / Sương nặng (delta <= 0) */
            else if (delta <= 0) {
                status_str = "SUONG NANG";
                fan_lv_out  = 3;   /* L3  */
                srv1_lv_out = 2;   /* MAX */
                srv2_lv_out = 2;   /* MAX */
            }
            /* P4: Cảnh báo sớm / Sương nhẹ (delta <= 5) */
            else if (delta <= 50) {
                status_str = "SUONG NHE";
                fan_lv_out  = 2;   /* L2  */
                srv1_lv_out = 0;   /* MID */
                srv2_lv_out = 0;   /* MID */
            }
            /* P5: An toàn (delta > 5) */
            else {
                status_str = "AN TOAN  ";
                fan_lv_out  = 1;   /* L1  */
                srv1_lv_out = 1;   /* OFF */
                srv2_lv_out = 1;   /* OFF */
            }
        }

        /* ---- Hiển thị status page 6 ---- */
        ssd1309_set_cursor(6, 30);
        ssd1309_write_string(status_str);

        /* ---- Điều khiển actuator ---- */
        if (is_manual_mode) {
            fan_level    = fan_level_manual;
            servo_level  = servo_level_manual;
            servo2_level = servo2_level_manual;

        } else {
            /* AUTO: dùng giá trị từ FSM */
            fan_level    = fan_lv_out;
            servo_level  = srv1_lv_out;
            servo2_level = srv2_lv_out;
        }

        /* ---- Cập nhật PWM ---- */
        fan_set_high_us(fan_high_levels[fan_level]);
        servo_set_high_us(servo_high_levels[servo_level]);
        servo2_set_high_us(servo_high_levels[servo2_level]);

        /* ---- Hiển thị actuator status page 7 ---- */
        ssd1309_set_cursor(7, 0);
        ssd1309_write_string("F:L");
        ssd1309_write_char('0' + fan_level);

        ssd1309_set_cursor(7, 32);
        ssd1309_write_string("S1:");
        ssd1309_write_string(servo_level == 0 ? "MID" : servo_level == 1 ? "OFF" : "MAX");

        ssd1309_set_cursor(7, 78);
        ssd1309_write_string("S2:");
        ssd1309_write_string(servo2_level == 0 ? "MID" : servo2_level == 1 ? "OFF" : "MAX");

        ssd1309_set_cursor(7, 122);
        ssd1309_write_char(is_manual_mode ? 'M' : 'A');
    }

    return 0;
}