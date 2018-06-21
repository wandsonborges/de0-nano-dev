#include "conv_driver.h"


#define LINES_MAX 4096
#define COLS_MAX 4096
#define FRAME_SIZE_MAX COLS_MAX*LINES_MAX
#define KERNEL_SIZE 3

#define NBITS_FRAC 0


uint8_t filter(int value)
{
  if (value > 255)
    return 255;
  else
    return value;
}


void swConvImg(uint8_t *imgOut, uint8_t *imgIn, uint32_t kernel[], int lines, int cols)
{
  int i, j, x, y, k = 0;
  int sum = 0;
  for (i = 0; i < lines-2; i++) {
    for (j = 0; j < cols-2; j++) {
      for (y = 0; y < KERNEL_SIZE; y++) {
	for (x = 0; x < KERNEL_SIZE; x++) {
	  //sum = sum + imgIn[y+i][x+j]*kernel[y*KERNEL_SIZE + x];	  
	  sum = sum + imgIn[(y+i)*cols + x+j]*kernel[y*KERNEL_SIZE + x];
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

void getImgRes(FILE *file, int* cols, int *lines)
{
  char header[10];
  int max;
  fgets(header, 10, file);
  fscanf(file, "%i", lines);
  fscanf(file, "%i", cols);
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
      fprintf(file, "%hu\n", imgIn[i*(cols-2) + j]);
    }
  }
}

void feedHwInput(int memD, uint8_t *img, uint32_t addrInit, int lines, int cols)
{
  void* addrInput = mmap(NULL,LINES_MAX*COLS_MAX,(PROT_READ|PROT_WRITE),MAP_SHARED,memD,addrInit);
  memcpy(addrInput, &img[0], lines*cols);
}

void getHwOutput(int memD, uint8_t *imgConv, uint32_t addrInit, int lines, int cols)
{
  void* addrInput = mmap(NULL,LINES_MAX*COLS_MAX,(PROT_READ|PROT_WRITE),MAP_SHARED,memD,addrInit);
  memcpy(&imgConv[0], addrInput, (lines-2)*(cols-2));
}


int main(int argc, char* argv[])
{

  uint32_t kernelValues[9] = {0, 0, 0, 0, 1, 0, 0, 0, 0};


  int forceSw = 0;
  
  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  printf("fd -> %i\n", fd);
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

    FILE  *finput = fopen(argv[1], "r");  
  if(!finput){
    fprintf(stderr,"Unable to open file in 'r' mode");
    exit(EXIT_FAILURE);
  }

  FILE  *fout = fopen(argv[2], "w");  
  if(!fout){
    fprintf(stderr,"Unable to open file in 'w' mode");
    exit(EXIT_FAILURE);
  }

  int lines, cols;
  getImgRes(finput, &lines, &cols);


  uint8_t *img = malloc(lines*cols);
  uint8_t *imgConv = malloc((lines-2)*(cols-2));
  printf("%i %i\n", lines, cols);
  
  forceSw = atoi(argv[3]);

  feedInputImg(finput, img, lines, cols);
  
  void* convConfigBase = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_ADDR_BASE) + CONV_CONFIG_OFFSET;

  if ((forceSw == 0) && checkConvHardware(convConfigBase)) {
    printf("HW DETECTED!!\n");
    setupConvHw(convConfigBase, lines, cols, 0x38000000, 0x38C00000, kernelValues);
    printConfigPointers(convConfigBase);
    feedHwInput(fd, img, 0x38000000, lines, cols);
    turnOnConv(convConfigBase);
    while(isBusy(convConfigBase)){}
    getHwOutput(fd, imgConv, 0x38C00000, lines, cols);
    
  }
  else
    {
      printf("HW NOT DETECTED!! Doing in software....\n");
      swConvImg(imgConv, img, kernelValues, lines, cols);
    }

  writeConvImg(fout, imgConv, lines, cols);  
}
