#include "fan.h"

#define FAN_CTRL_REG      (*(volatile unsigned int *)0x80000028)
#define FAN_PRESCALE_REG  (*(volatile unsigned int *)0x8000002C)
#define FAN_PERIOD_REG    (*(volatile unsigned int *)0x80000030)
#define FAN_COMPARE_REG   (*(volatile unsigned int *)0x80000034)
#define FAN_COUNTER_REG   (*(volatile unsigned int *)0x80000038)

#define PWM_CTRL_ENABLE   0x00000001u
#define PWM_CTRL_POLARITY 0x00000004u
#define PWM_1US_PRESCALE  27u

void fan_set_period_us(unsigned short period_us)
{
    FAN_PRESCALE_REG = PWM_1US_PRESCALE;
    FAN_PERIOD_REG = period_us;
}

void fan_set_high_us(unsigned short high_us)
{
    FAN_COMPARE_REG = high_us;
}

void fan_enable(void)
{
    FAN_CTRL_REG = PWM_CTRL_ENABLE;
}

void fan_disable(void)
{
    FAN_CTRL_REG = 0;
}

unsigned short fan_get_period_us(void)
{
    return FAN_PERIOD_REG;
}

unsigned short fan_get_high_us(void)
{
    return FAN_COMPARE_REG;
}

unsigned char fan_is_enabled(void)
{
    return (unsigned char)(FAN_CTRL_REG & PWM_CTRL_ENABLE);
}
