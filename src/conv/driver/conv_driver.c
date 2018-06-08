#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>

#define LW_ADDR_BASE 0xFF200000
#define CONV_CONFIG_OFFSET 0x10000
#define LW_SPAN 0x80000

#define ADDR_SPAN 0x4000000

// - Add Vector HW Opcode
#define SIGNATURE 0x33221100

// - Conv HW Control Registers
#define FIRE_REG_OFFSET 0

#define NUMBER_OF_CONFIG_REGS 2

uint32_t* getRegisters(void* mem)
{
  uint32_t *addVectorConfigRegs = (uint32_t*) (mem);
        return addVectorConfigRegs;
}

void printConfigPointers(void* mem)
{
  int i = 0;
  for(i=0; i< NUMBER_OF_CONFIG_REGS;i++)
    printf("reg[%i] = %x\n", i, ((uint32_t*) mem)[i]);
}
      
void turnOffConv(void* mem)
{
	*((uint32_t*)(mem)+FIRE_REG_OFFSET) = 0;
}

void turnOnConv(void* mem)
{
	*((uint32_t*)(mem)+FIRE_REG_OFFSET) = 1;
	turnOffConv(mem);
}

int checkConvHardware(int memFd)
{
        void* mem = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,memFd,LW_ADDR_BASE) + CONV_CONFIG_OFFSET;
	uint32_t* regs = getRegisters(mem);
	if (regs[0] == SIGNATURE) return 1;
	else return 0;
}



int main(int argc, char* argv[])
{

  
  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  printf("fd -> %i\n", fd);
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

  void* convConfigBase = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_ADDR_BASE) + CONV_CONFIG_OFFSET;

  printConfigPointers(convConfigBase);
  turnOnConv(convConfigBase);
  
}
