#include "conv_driver.h"

#define F2H_ADDR_BASE 0xC0000000
#define F2H_SPAN 0x10000000

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

void swConvImg(uint8_t imgOut[LINES-2][COLS-2], uint8_t imgIn[LINES][COLS], uint32_t kernel[])
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

void feedHwInput(int memD, uint8_t img[LINES][COLS], uint32_t addrInit)
{
  void* addrInput = mmap(NULL,LINES*COLS,(PROT_READ|PROT_WRITE),MAP_SHARED,memD,addrInit);
  memcpy(addrInput, &img[0][0], LINES*COLS);
}

void getHwOutput(int memD, uint8_t imgConv[LINES-2][COLS-2], uint32_t addrInit)
{
  void* addrInput = mmap(NULL,LINES*COLS,(PROT_READ|PROT_WRITE),MAP_SHARED,memD,addrInit);
  memcpy(&imgConv[0][0], addrInput, (LINES-2)*(COLS-2));
}


int main(int argc, char* argv[])
{

  uint32_t kernelValues[9] = {0, 0, 0, 0, 1, 0, 0, 0, 0};
  uint8_t img[LINES][COLS];
  uint8_t imgConv[LINES-2][COLS-2];


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

  forceSw = atoi(argv[3]);

  feedInputImg(finput, img);
  
  void* convConfigBase = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_ADDR_BASE) + CONV_CONFIG_OFFSET;

  void* convDataBase = mmap(NULL,F2H_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,F2H_ADDR_BASE);


  if ((forceSw == 0) && checkConvHardware(convConfigBase)) {
    printf("HW DETECTED!!\n");
    setupConvHw(convConfigBase, LINES, COLS, 0x00000000, 0x00C00000, kernelValues);
    printConfigPointers(convConfigBase);
    feedHwInput(fd, img, 0x00000000);
    turnOnConv(convConfigBase);
    while(isBusy(convConfigBase)){}
    getHwOutput(fd, imgConv, 0x00C00000);
    
  }
  else
    {
      printf("HW NOT DETECTED!! Doing in software....\n");
      swConvImg(imgConv, img, kernelValues);
    }

  
  writeConvImg(fout, imgConv);

  
}
