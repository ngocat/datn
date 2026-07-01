#include "aht20.h"
#include "i2c.h"
#include "countdown_timer.h"

static unsigned int mul125(unsigned int x)
{
    return (x << 7) - (x << 2) + x;
}

void aht20_init(unsigned char addr)
{
    cdt_delay(1080000);

    i2c_start();
    i2c_write_byte(addr << 1);
    i2c_write_byte(0xBE);
    i2c_write_byte(0x08);
    i2c_write_byte(0x00);
    i2c_stop();

    cdt_delay(270000);
}

int aht20_read(unsigned char addr, int *temp_x10, int *hum_x10)
{
    unsigned char data[6];
    unsigned int raw_hum, raw_temp;
    int i;

    i2c_start();
    i2c_write_byte(addr << 1);
    i2c_write_byte(0xAC);
    i2c_write_byte(0x33);
    i2c_write_byte(0x00);
    i2c_stop();

    cdt_delay(2160000);

    i2c_start();
    i2c_write_byte((addr << 1) | 1);
    for (i = 0; i < 5; i++)
        data[i] = i2c_read_byte(1);
    data[5] = i2c_read_byte(0);
    i2c_stop();

    if (data[0] & 0x80)
        return -1;

    raw_hum = ((unsigned int)data[1] << 12) |
              ((unsigned int)data[2] << 4) |
              (data[3] >> 4);

    raw_temp = (((unsigned int)data[3] & 0x0F) << 16) |
               ((unsigned int)data[4] << 8) |
               data[5];

    *hum_x10 = (int)(mul125(raw_hum) >> 17);
    *temp_x10 = (int)(mul125(raw_temp) >> 16) - 500;

    return 0;
}
