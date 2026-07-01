#ifndef AHT20_B2_H
#define AHT20_B2_H

void aht20_init_b2(unsigned char addr);
int aht20_read_b2(unsigned char addr, int *temp_x10, int *hum_x10);

#endif
