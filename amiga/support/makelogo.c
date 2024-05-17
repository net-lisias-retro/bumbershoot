#include <stdio.h>
#include <stdint.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_PNG_ONLY
#include "stb_image.h"

uint8_t logo[14336];
uint8_t bps[1792][5];
uint16_t palette[32];

void convert(unsigned char *img)
{
    int x, y, i;
    /* Preload initial palette */
    palette[0] = 0x05a;
    palette[1] = 0xfff;
    palette[2] = 0x000;
    for (i = 3; i < 32; ++i) {
        palette[i] = 0;
    }
    /* Clear image */
    for (i = 0; i < 14336; ++i) {
        logo[i] = 0;
    }
    /* Convertible pixels go in columns 6-105 */
    for (y = 0; y < 128; ++y) {
        int row = y * 100;
        for (x = 0; x < 100; ++x) {
            int i = (row + x) * 4;
            int r = img[i] >> 4;
            int g = img[i+1] >> 4;
            int b = img[i+2] >> 4;
            int col = r + (g << 4) + (b << 8);
            if (col != 0) {
                /* Black stays black; everything else, we find it in
                 * the palette and add it if it's not there */
                for (i = 1; i < 32; ++i) {
                    if (palette[i] == col) {
                        break;
                    }
                    if (i != 2 && palette[i] == 0) {
                        palette[i] = col;
                        break;
                    }
                }
                if (i == 32) {
                    printf("Out of palette space!\n");
                    return;
                }
            } else {
                i = 2;
            }
            logo[y * 112 + x + 6] = i;
        }
    }
}

void encode(FILE *f, uint8_t *buf, int width, int height)
{
    int x, y;
    if (!f) {
        return;
    }
    for (y = 0; y < 1792; ++y) {
        for (x = 0; x < 5; ++x) {
            bps[y][x] = 0;
        }
    }
    for (y = 0; y < height; ++y) {
        for (x = 0; x < width; x += 8) {
            int i, j;
            int n = y * 14 + (x >> 3);
            for (i = 0; i < 8; ++i) {
                int v = buf[y * width + x + i];
                for (j = 0; j < 5; ++j) {
                    bps[n][j] <<= 1;
                    if (v & 1) {
                        bps[n][j] |= 1;
                    }
                    v >>= 1;
                }
            }
        }
    }
    for (y = 0; y < 5; y += 1) {
        for (x = 0; x < 1792; ++x) {
            fputc(bps[x][y], f);
        }
    }
}

int main(int argc, char **argv)
{
    int w, h, n;
    unsigned char *p;
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }
    unsigned char *img = stbi_load(argv[1], &w, &h, &n, 4);
    if (!img) {
        fprintf(stderr, "Could not load %s\n", argv[1]);
        return 1;
    }
    if (w != 100 || h != 128) {
        printf("This is not the correct source image\n");
        stbi_image_free(img);
        return 1;
    }
    convert(img);
    FILE *f = fopen("bumberlogo.bin", "wb");
    if (f) {
        encode(f, logo, 112, 128);
        for (n = 0; n < 32; ++n) {
            fputc(palette[n] >> 8, f);
            fputc(palette[n] & 0xff, f);
        }
        fclose(f);
    }
    stbi_image_free(img);
    return 0;
}
