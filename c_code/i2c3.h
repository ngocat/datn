#ifndef I2C3_H
#define I2C3_H

void i2c3_init(void);
void i2c3_start(void);
void i2c3_stop(void);
int i2c3_write_byte(unsigned char data);
unsigned char i2c3_read_byte(int ack);

#endif
