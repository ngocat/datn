#ifndef AHT20_H
#define AHT20_H

void aht20_init(unsigned char addr);
int aht20_read(unsigned char addr, int *temp_x10, int *hum_x10);

#endif
