#include "i2c3.h"

#define I2C3_REG ((volatile unsigned int *) 0x8000006C)
#define SCL_BIT 0x01
#define SDA_BIT 0x02

static unsigned int i2c3_out = 0x03;

static void i2c3_delay(void)
{
    volatile int i;
    for (i = 0; i < 5; i++);
}

static void set_scl(int high)
{
    if (high)
        i2c3_out |= SCL_BIT;
    else
        i2c3_out &= ~SCL_BIT;
    *I2C3_REG = i2c3_out;
}

static void set_sda(int high)
{
    if (high)
        i2c3_out |= SDA_BIT;
    else
        i2c3_out &= ~SDA_BIT;
    *I2C3_REG = i2c3_out;
}

static int read_sda(void)
{
    return (*I2C3_REG >> 1) & 1;
}

void i2c3_init(void)
{
    i2c3_out = SCL_BIT | SDA_BIT;
    *I2C3_REG = i2c3_out;
    i2c3_delay();
}

void i2c3_start(void)
{
    set_sda(1);
    i2c3_delay();
    set_scl(1);
    i2c3_delay();
    set_sda(0);
    i2c3_delay();
    set_scl(0);
    i2c3_delay();
}

void i2c3_stop(void)
{
    set_sda(0);
    i2c3_delay();
    set_scl(1);
    i2c3_delay();
    set_sda(1);
    i2c3_delay();
}

int i2c3_write_byte(unsigned char data)
{
    int i, ack;

    for (i = 7; i >= 0; i--) {
        set_sda((data >> i) & 1);
        i2c3_delay();
        set_scl(1);
        i2c3_delay();
        set_scl(0);
        i2c3_delay();
    }

    set_sda(1);
    i2c3_delay();
    set_scl(1);
    i2c3_delay();
    ack = read_sda();
    set_scl(0);
    i2c3_delay();

    return ack;
}

unsigned char i2c3_read_byte(int ack)
{
    int i;
    unsigned char data = 0;

    set_sda(1);

    for (i = 7; i >= 0; i--) {
        i2c3_delay();
        set_scl(1);
        i2c3_delay();
        if (read_sda())
            data |= (1 << i);
        set_scl(0);
    }

    set_sda(ack ? 0 : 1);
    i2c3_delay();
    set_scl(1);
    i2c3_delay();
    set_scl(0);
    i2c3_delay();
    set_sda(1);

    return data;
}
