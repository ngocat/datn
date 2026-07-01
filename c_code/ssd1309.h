#ifndef SSD1309_H
#define SSD1309_H

#define CHAR_DEGREE 127

void ssd1309_init(void);
void ssd1309_clear(void);
void ssd1309_set_cursor(int page, int col);
void ssd1309_write_char(char c);
void ssd1309_write_string(const char *str);

#endif