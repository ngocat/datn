#ifndef I2C2_H
#define I2C2_H

void i2c2_init(void);
void i2c2_start(void);
void i2c2_stop(void);
int i2c2_write_byte(unsigned char data);
unsigned char i2c2_read_byte(int ack);

#endif
