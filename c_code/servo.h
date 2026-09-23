#ifndef SERVO_H
#define SERVO_H

extern void servo_set_period_us(unsigned short period_us);
extern void servo_set_high_us(unsigned short high_us);
extern void servo_enable(void);
extern void servo_disable(void);
extern unsigned short servo_get_period_us(void);
extern unsigned short servo_get_high_us(void);
extern unsigned char servo_is_enabled(void);

#endif