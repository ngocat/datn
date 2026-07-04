
#include "gpio.h"

#define GPIO_REG ((volatile unsigned int *)0x80000068)

void set_gpio(unsigned int val)
{
  *GPIO_REG = val;
}

unsigned int get_gpio(void)
{
  return *GPIO_REG;
}
