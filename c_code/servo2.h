#ifndef SERVO2_H
#define SERVO2_H

extern void servo2_set_period_us(unsigned short period_us);
extern void servo2_set_high_us(unsigned short high_us);
extern void servo2_enable(void);
extern void servo2_disable(void);
extern unsigned short servo2_get_period_us(void);
extern unsigned short servo2_get_high_us(void);
extern unsigned char servo2_is_enabled(void);

#endif
