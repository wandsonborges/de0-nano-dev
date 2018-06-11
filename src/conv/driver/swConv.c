#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>


#define LINES 480
#define COLS 640
#define FRAME_SIZE COLS*LINES
#define KERNEL_SIZE 3

#define NBITS_FRAC 0

uint8_t filter(int value)
{
  if (value > 255)
    return 255;
  else
    return value;
}

void convImg(uint8_t imgOut[LINES-2][COLS-2], uint8_t imgIn[LINES][COLS], uint32_t kernel[])
{
  int i, j, x, y, k = 0;
  int sum = 0;
  for (i = 0; i < LINES-2; i++) {
    for (j = 0; j < COLS-2; j++) {
      for (y = 0; y < KERNEL_SIZE; y++) {
	for (x = 0; x < KERNEL_SIZE; x++) {
	  //if (i == 0 && j ==0) printf("SOMANDO: %i %i\n", imgIn[y+i][x+j], kernel[y*KERNEL_SIZE + x]);  
	  sum = sum + imgIn[y+i][x+j]*kernel[y*KERNEL_SIZE + x];
	}
      }
      imgOut[i][j] = filter(sum);
      sum = 0;
    }
  }
}

void feedInputImg(FILE *file, uint8_t imgIn[LINES][COLS])
{
  static uint8_t pxl;
  static int i = 0;
  static int j = 0;
  for (i = 0; i < LINES; i++) {
    for (j = 0; j < COLS; j++) {
      fscanf(file, "%hu", &pxl);
      imgIn[i][j] = pxl;
    }
  }
}

void writeConvImg(FILE *file, uint8_t imgIn[LINES-2][COLS-2])
{
  static uint8_t pxl;
  static int i = 0;
  static int j = 0;
  fprintf(file, "P2\n%i %i\n255\n", COLS-2, LINES-2);
  for (i = 0; i < LINES-2; i++) {
    for (j = 0; j < COLS-2; j++) {
      fprintf(file, "%hu\n", imgIn[i][j]);
    }
  }
}


int main(int argc, char* argv[])
{

  uint32_t kernelValues[9] = {0, 0, 0, 0, 2, 0, 0, 0, 0};
    
  uint8_t img[LINES][COLS];
  uint8_t imgConv[LINES-2][COLS-2];
  
  FILE  *fp = fopen(argv[1], "r");  
  if(!fp){
    fprintf(stderr,"Unable to open file in 'r' mode");
    exit(EXIT_FAILURE);
  }

  FILE  *fout = fopen(argv[2], "w");  
  if(!fp){
    fprintf(stderr,"Unable to open file in 'w' mode");
    exit(EXIT_FAILURE);
  }

  
  feedInputImg(fp, img);
  printf("pxl[0][0] = %hu", img[0][0]);
  convImg(imgConv, img, kernelValues);
  printf("pxl[0][0] = %hu", imgConv[0][0]);

  writeConvImg(fout, imgConv);
	  
  }
