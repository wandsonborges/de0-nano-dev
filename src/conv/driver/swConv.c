#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>


#define KERNEL_SIZE 3

#define NBITS_FRAC 0

uint8_t filter(int value)
{
  if (value > 255)
    return 255;
  else
    return value;
}

void convImg(uint8_t *imgOut, uint8_t *imgIn, uint32_t kernel[], int lines, int cols)
{
  int i, j, x, y, k = 0;
  int sum = 0;
  for (i = 0; i < lines-2; i++) {
    for (j = 0; j < cols-2; j++) {
      for (y = 0; y < KERNEL_SIZE; y++) {
	for (x = 0; x < KERNEL_SIZE; x++) {
	  //sum = sum + imgIn[y+i][x+j]*kernel[y*KERNEL_SIZE + x];	  
	  sum = sum + imgIn[(y+i)*cols + x+j]*kernel[y*KERNEL_SIZE + x];
	  if (i ==0 && j ==0) printf("s = %i %i %i\n", sum, imgIn[(y+i)*cols + x+j], kernel[y*KERNEL_SIZE + x]);
	}
      }
      imgOut[i*cols + j] = filter(sum);
      sum = 0;
    }
  }
}

void feedInputImg(FILE *file, uint8_t *imgIn, int lines, int cols)
{
  static uint8_t pxl;
  static int i = 0;
  static int j = 0;
  for (i = 0; i < lines; i++) {
    for (j = 0; j < cols; j++) {
      fscanf(file, "%hu", &pxl);
      imgIn[i*cols + j] = pxl;
    }
  }
}

void getImgRes(FILE *file, int* lines, int *cols)
{
  char header[10];
  int max;
  fgets(header, 10, file);
  fscanf(file, "%i", cols);
  fscanf(file, "%i", lines);
  fscanf(file, "%i", &max);
  
}
void writeConvImg(FILE *file, uint8_t *imgIn, int lines, int cols)
{
  static uint8_t pxl;
  static int i = 0;
  static int j = 0;
  fprintf(file, "P2\n%i %i\n255\n", cols-2, lines-2);
  for (i = 0; i < lines-2; i++) {
    for (j = 0; j < cols-2; j++) {
      fprintf(file, "%hu\n", imgIn[i*cols + j]);
    }
  }
}


int main(int argc, char* argv[])
{

  uint32_t kernelValues[9] = {0, 0, 0, 0, 1, 0, 0, 0, 0};
    
  
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

  int lines, cols;
  getImgRes(fp, &lines, &cols);


  uint8_t *img = malloc(lines*cols);
  uint8_t *imgConv = malloc((lines-2)*(cols-2));

  printf("%i %i\n", lines, cols);
  feedInputImg(fp, img, lines, cols);
  printf("pxl[0][0] = %hu", img[cols+1]);
  convImg(imgConv, img, kernelValues, lines, cols);
  printf("pxl[0][0] = %hu", imgConv[0]);

  writeConvImg(fout, imgConv, lines, cols);
	  
  }
