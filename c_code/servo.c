#include "servo.h"

#define SERVO_CTRL_REG      (*(volatile unsigned int *)0x8000003C)
#define SERVO_PRESCALE_REG  (*(volatile unsigned int *)0x80000040)
#define SERVO_PERIOD_REG    (*(volatile unsigned int *)0x80000044)
#define SERVO_COMPARE_REG   (*(volatile unsigned int *)0x80000048)
#define SERVO_COUNTER_REG   (*(volatile unsigned int *)0x8000004C)

#define PWM_CTRL_ENABLE   0x00000001u
#define PWM_CTRL_POLARITY 0x00000004u
#define PWM_1US_PRESCALE  27u

void servo_set_period_us(unsigned short period_us)
{
    SERVO_PRESCALE_REG = PWM_1US_PRESCALE;
    SERVO_PERIOD_REG = period_us;
}

void servo_set_high_us(unsigned short high_us)
{
    SERVO_COMPARE_REG = high_us;
}

void servo_enable(void)
{
    SERVO_CTRL_REG = PWM_CTRL_ENABLE;
}

void servo_disable(void)
{
    SERVO_CTRL_REG = 0;
}

unsigned short servo_get_period_us(void)
{
    return SERVO_PERIOD_REG;
}

unsigned short servo_get_high_us(void)
{
    return SERVO_COMPARE_REG;
}

unsigned char servo_is_enabled(void)
{
    return (unsigned char)(SERVO_CTRL_REG & PWM_CTRL_ENABLE);
}
