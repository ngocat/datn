#include "i2c2.h"

#define I2C2_REG ((volatile unsigned int *) 0x80000024)
#define SCL_BIT 0x01
#define SDA_BIT 0x02

static unsigned int i2c2_out = 0x03;

static void i2c2_delay(void)
{
    volatile int i;
    for (i = 0; i < 5; i++);
}

static void set_scl(int high)
{
    if (high)
        i2c2_out |= SCL_BIT;
    else
        i2c2_out &= ~SCL_BIT;
    *I2C2_REG = i2c2_out;
}

static void set_sda(int high)
{
    if (high)
        i2c2_out |= SDA_BIT;
    else
        i2c2_out &= ~SDA_BIT;
    *I2C2_REG = i2c2_out;
}

static int read_sda(void)
{
    return (*I2C2_REG >> 1) & 1;
}

void i2c2_init(void)
{
    i2c2_out = SCL_BIT | SDA_BIT;
    *I2C2_REG = i2c2_out;
    i2c2_delay();
}

void i2c2_start(void)
{
    set_sda(1);
    i2c2_delay();
    set_scl(1);
    i2c2_delay();
    set_sda(0);
    i2c2_delay();
    set_scl(0);
    i2c2_delay();
}

void i2c2_stop(void)
{
    set_sda(0);
    i2c2_delay();
    set_scl(1);
    i2c2_delay();
    set_sda(1);
    i2c2_delay();
}

int i2c2_write_byte(unsigned char data)
{
    int i, ack;

    for (i = 7; i >= 0; i--) {
        set_sda((data >> i) & 1);
        i2c2_delay();
        set_scl(1);
        i2c2_delay();
        set_scl(0);
        i2c2_delay();
    }

    set_sda(1);
    i2c2_delay();
    set_scl(1);
    i2c2_delay();
    ack = read_sda();
    set_scl(0);
    i2c2_delay();

    return ack;
}

unsigned char i2c2_read_byte(int ack)
{
    int i;
    unsigned char data = 0;

    set_sda(1);

    for (i = 7; i >= 0; i--) {
        i2c2_delay();
        set_scl(1);
        i2c2_delay();
        if (read_sda())
            data |= (1 << i);
        set_scl(0);
    }

    set_sda(ack ? 0 : 1);
    i2c2_delay();
    set_scl(1);
    i2c2_delay();
    set_scl(0);
    i2c2_delay();
    set_sda(1);

    return data;
}
