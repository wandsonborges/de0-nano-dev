#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>

#define LW_ADDR_BASE 0xFF200000
#define HOMOG_CONFIG_OFFSET 0x40
#define LW_SPAN 0x100

#define HOMOG_CONFIG_SELECT_OFFSET 2
#define HOMOG_CONFIG_INPUTS_OFFSET 3

#define HOMOG_SIZE 3*3
void* homogConfig_base;


uint32_t* getRegisters(void* mem)
{
  uint32_t *homog_input = (uint32_t*) (mem);
        return homog_input;
}

void selectMatrix(void* mem, int n)
{
  *((uint32_t*)(mem) + HOMOG_CONFIG_SELECT_OFFSET) = n; 
}

void setHomog(void* mem, int32_t* inputs) 
 { 
 	int i = 0; 
 	for (i=0; i < HOMOG_SIZE; i++) 
 	{ 
 		*((int32_t*)(mem) + HOMOG_CONFIG_INPUTS_OFFSET + i) = inputs[i]; 
 	} 
	
 } 


int main(int argc, char* argv[]){
  int i=0;
  FILE* fout;


  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

  homogConfig_base = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_ADDR_BASE) + HOMOG_CONFIG_OFFSET;
  if (homogConfig_base == MAP_FAILED) {
	close(fd);
	perror("Error mmapping the file");
	exit(EXIT_FAILURE);
    }
  

  int32_t homog[9] = {748982, -748982, 0, 748982, 748982, 0, 0, 0, 1048576};

  selectMatrix(homogConfig_base, atoi(argv[1]));
  setHomog(homogConfig_base, homog);

  uint32_t* var = (uint32_t*)homogConfig_base + HOMOG_CONFIG_OFFSET; 
  printf("CONFIG: %x\n", var[0]); 
  for (i=0; i < 12; i++)
    printf("reg[%i] = %x\n", i,var[i]);

}

