#ifndef I2C_H
#define I2C_H

void i2c_init(void);
void i2c_start(void);
void i2c_stop(void);
int i2c_write_byte(unsigned char data);
unsigned char i2c_read_byte(int ack);

#endif
