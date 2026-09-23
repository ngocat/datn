#include "servo2.h"

#define SERVO2_CTRL_REG      (*(volatile unsigned int *)0x80000050)
#define SERVO2_PRESCALE_REG  (*(volatile unsigned int *)0x80000054)
#define SERVO2_PERIOD_REG    (*(volatile unsigned int *)0x80000058)
#define SERVO2_COMPARE_REG   (*(volatile unsigned int *)0x8000005C)
#define SERVO2_COUNTER_REG   (*(volatile unsigned int *)0x80000060)

#define PWM_CTRL_ENABLE   0x00000001u
#define PWM_CTRL_POLARITY 0x00000004u
#define PWM_1US_PRESCALE  27u

void servo2_set_period_us(unsigned short period_us)
{
    SERVO2_PRESCALE_REG = PWM_1US_PRESCALE;
    SERVO2_PERIOD_REG = period_us;
}

void servo2_set_high_us(unsigned short high_us)
{
    SERVO2_COMPARE_REG = high_us;
}

void servo2_enable(void)
{
    SERVO2_CTRL_REG = PWM_CTRL_ENABLE;
}

void servo2_disable(void)
{
    SERVO2_CTRL_REG = 0;
}

unsigned short servo2_get_period_us(void)
{
    return SERVO2_PERIOD_REG;
}

unsigned short servo2_get_high_us(void)
{
    return SERVO2_COMPARE_REG;
}

unsigned char servo2_is_enabled(void)
{
    return (unsigned char)(SERVO2_CTRL_REG & PWM_CTRL_ENABLE);
}
