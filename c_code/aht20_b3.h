#ifndef AHT20_B3_H
#define AHT20_B3_H

void aht20_init_b3(unsigned char addr);
int aht20_read_b3(unsigned char addr, int *temp_x10, int *hum_x10);

#endif
