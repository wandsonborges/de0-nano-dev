#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <errno.h>


#define IMG_ADDR 0x38000000
#define IMG_SPAN 0x100000

#define FRAME_SIZE 640*480
void* img_base;
int main(int argc, char* argv[])
{

  
  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

  img_base = mmap(NULL,IMG_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,IMG_ADDR);

    printf("start0\n");
  if (img_base == MAP_FAILED) {
	close(fd);
	perror("Error mmapping the file");
	exit(EXIT_FAILURE);
    }

  
  FILE  *fp = fopen(argv[1], "r");  
  if(!fp){
    fprintf(stderr,"Unable to open file in 'r' mode");
    exit(errno);
  }

  printf("start1\n");
  uint8_t* img = malloc(FRAME_SIZE);
  uint8_t pxl = 0;
  int offset = 0;
  while(!feof(fp) ){
    fscanf(fp, "%hu", &pxl);
    *((uint8_t*) img_base + offset) = pxl;
    offset++;
}
  int i = 0;

}
