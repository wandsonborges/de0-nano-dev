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
#define ARRAY_SIZE_IN_REG 1
#define ARRAY_SIZE_OUT_REG 2
#define ADDR_BASE_RD 3
#define ADDR_BASE_WR 4
#define INIT_KERNEL_CONFIG_REG 5

#define REG_IMG_COL_SIZE 14
#define REG_IMG_LINE_SIZE 15
#define BUSY_REG 16

#define NUMBER_OF_CONFIG_REGS 17

#define NUM_KERNEL_ELEMENTS 9

uint32_t* getRegisters(void* mem)
{
  uint32_t *addVectorConfigRegs = (uint32_t*) (mem);
        return addVectorConfigRegs;
}

void printConfigPointers(void* mem)
{
  int i = 0;
  printf("CONVOLUTION HARDWARE REGS: \n");
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

int checkConvHardware(void* mem)
{
	uint32_t* regs = getRegisters(mem);
	if (regs[0] == SIGNATURE) return 1;
	else return 0;
}

void setArrayInputSize(void* mem, uint32_t arraySize)
{
  *((uint32_t*)(mem)+ARRAY_SIZE_IN_REG) = arraySize;
}

void setArrayOutputSize(void* mem, uint32_t arraySize)
{
  *((uint32_t*)(mem)+ARRAY_SIZE_OUT_REG) = arraySize;
}

void setInputPointer(void* mem, uint32_t inputPointer)
{
  *((uint32_t*)(mem)+ADDR_BASE_RD) = inputPointer;
}

void setOutputPointer(void* mem, uint32_t outputPointer)
{
  *((uint32_t*)(mem)+ADDR_BASE_WR) = outputPointer;
}

void setImgSize(void* mem, int cols, int lines)
{
  *((uint32_t*)(mem)+REG_IMG_COL_SIZE) = cols;
  *((uint32_t*)(mem)+REG_IMG_LINE_SIZE) = lines;
}

void setConvKernel(void* mem, uint32_t kernel[])
{
  int i = 0;
  for (i = 0; i < NUM_KERNEL_ELEMENTS; i++)
    *((uint32_t*)(mem)+INIT_KERNEL_CONFIG_REG + i) = kernel[i];
    
}

int isBusy(void* mem)
{
  return *((uint32_t*)(mem)+BUSY_REG);
}

void setupConvHw(void* configMem, int lines, int cols, uint32_t addrIn, uint32_t addrOut, uint32_t kernel[]) {
  setArrayInputSize(configMem, lines*cols);
  setArrayOutputSize(configMem, (lines-2)*(cols-2));
  setInputPointer(configMem, addrIn);
  setOutputPointer(configMem, addrOut);
  setConvKernel(configMem, kernel);
  setImgSize(configMem, cols, lines);
}
