# Just run "make" to create ../src/mem_init.v

CFLAGS = -mno-save-restore -march=rv32i2p0 -mabi=ilp32 -nostartfiles -nostdlib -static -Os -ffunction-sections -fdata-sections

CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

OBJS = main.o countdown_timer.o uart.o leds.o gpio.o i2c.o i2c2.o i2c3.o ssd1309.o aht20.o aht20_b2.o aht20_b3.o fan.o servo.o servo2.o

all: mem_init.v prog.hex conv_to_init

conv_to_init: conv_to_init.c
	gcc -o conv_to_init conv_to_init.c

mem_init.v: prog.bin conv_to_init
	./conv_to_init prog.bin > mem_init.v

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

countdown_timer.o: countdown_timer.c
	$(CC) $(CFLAGS) -c countdown_timer.c

uart.o: uart.c
	$(CC) $(CFLAGS) -c uart.c

leds.o: leds.c
	$(CC) $(CFLAGS) -c leds.c

gpio.o: gpio.c
	$(CC) $(CFLAGS) -c gpio.c

i2c.o: i2c.c
	$(CC) $(CFLAGS) -c i2c.c

i2c2.o: i2c2.c
	$(CC) $(CFLAGS) -c i2c2.c

i2c3.o: i2c3.c
	$(CC) $(CFLAGS) -c i2c3.c

ssd1309.o: ssd1309.c
	$(CC) $(CFLAGS) -c ssd1309.c

aht20.o: aht20.c
	$(CC) $(CFLAGS) -c aht20.c

aht20_b2.o: aht20_b2.c
	$(CC) $(CFLAGS) -c aht20_b2.c

aht20_b3.o: aht20_b3.c
	$(CC) $(CFLAGS) -c aht20_b3.c

fan.o: fan.c fan.h
	$(CC) $(CFLAGS) -c fan.c

servo.o: servo.c servo.h
	$(CC) $(CFLAGS) -c servo.c

servo2.o: servo2.c servo2.h
	$(CC) $(CFLAGS) -c servo2.c

prog.elf: startup.s $(OBJS)
	$(CC) $(CFLAGS) -Tlink_cmd.ld -Wl,--gc-sections -o prog.elf startup.s $(OBJS)

prog.bin: prog.elf
	$(OBJCOPY) prog.elf -O binary prog.bin

prog.hex: prog.bin
	od -v -Ax -t x4 prog.bin > prog.hex

clean:
	rm -f prog.elf prog.hex prog.bin conv_to_init conv_to_init.exe i2c2.o aht20_b2.o fan.o servo.o servo2.o $(OBJS)
