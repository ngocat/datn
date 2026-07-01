#ifndef FAN_H
#define FAN_H

extern void fan_set_period_us(unsigned short period_us);
extern void fan_set_high_us(unsigned short high_us);
extern void fan_enable(void);
extern void fan_disable(void);
extern unsigned short fan_get_period_us(void);
extern unsigned short fan_get_high_us(void);
extern unsigned char fan_is_enabled(void);

#endif