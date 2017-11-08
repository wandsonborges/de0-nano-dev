#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>

#define LW_ADDR_BASE 0xFF200000
#define ADD_VECTOR_CONFIG_OFFSET 0x1000
#define LW_SPAN 0x80000

#define ADDR_SPAN 0x4000000

// - Add Vector HW Opcode
#define SIGNATURE 0x11223344

// - Add Vector HW Control Registers
#define BUSY_REG_OFFSET 6
#define ADDR_RESULT_REG_OFFSET 5
#define ADDR2_REG_OFFSET 4
#define ADDR1_REG_OFFSET 3
#define FIRE_REG_OFFSET 2
#define VEC_SIZE_REG_OFFSET 1

#define NUMBER_OF_CONFIG_REGS 7

uint32_t* getRegisters(void* mem)
{
  uint32_t *addVectorConfigRegs = (uint32_t*) (mem);
        return addVectorConfigRegs;
}

void setVectorsPointers(void* mem, uint32_t pointer1, uint32_t pointer2, uint32_t pointer3)
{
  *((uint32_t*)(mem) + ADDR1_REG_OFFSET) = pointer1;
  *((uint32_t*)(mem) + ADDR2_REG_OFFSET) = pointer2;
  *((uint32_t*)(mem) + ADDR_RESULT_REG_OFFSET) = pointer3;
}

void printVectorPointers(void* mem)
{
  int i = 0;
  for(i=0; i< NUMBER_OF_CONFIG_REGS;i++)
    printf("reg[%i] = %i\n", i, ((uint32_t*) mem)[i]);
}
      
void setVectorSize(void* mem, uint32_t newSize)
{
	*((uint32_t*)(mem) + VEC_SIZE_REG_OFFSET) = newSize;
}

void turnOffAddVector(void* mem)
{
	*((uint32_t*)(mem)+FIRE_REG_OFFSET) = 0;
}

void turnOnAddVector(void* mem)
{
	*((uint32_t*)(mem)+FIRE_REG_OFFSET) = 1;
	turnOffAddVector(mem);
}
uint32_t getVectorSize(void* mem)
{
	uint32_t* vectorSize = (uint32_t*) (mem);
	return vectorSize[VEC_SIZE_REG_OFFSET];
}

int checkAddVectorHardware(int memFd)
{
        void* mem = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,memFd,LW_ADDR_BASE) + ADD_VECTOR_CONFIG_OFFSET;
	uint32_t* regs = getRegisters(mem);
	if (regs[0] == SIGNATURE) return 1;
	else return 0;
}

uint32_t* hwAddVector(uint32_t size, uint32_t* v1, uint32_t* v2, int memFileDescriptor, uint32_t FPGA_InputPointer, uint32_t FPGA_ResultPointer)
{
  printf("hwAddVector call --\n");

  void* addVectorConfigBase = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,memFileDescriptor,LW_ADDR_BASE) + ADD_VECTOR_CONFIG_OFFSET;
  void* addrInput = mmap(NULL,size*2*4,(PROT_READ|PROT_WRITE),MAP_SHARED,memFileDescriptor,FPGA_InputPointer);
  void* resultBase = mmap(NULL,size,(PROT_READ|PROT_WRITE),MAP_SHARED,memFileDescriptor,FPGA_ResultPointer);
  if (addVectorConfigBase == MAP_FAILED || addrInput == MAP_FAILED || resultBase == MAP_FAILED) {
	close(memFileDescriptor);
	perror("Error mmapping the file addVConfigBase");
	exit(EXIT_FAILURE);
    }

  uint32_t* addrInput2 = ((uint32_t*) addrInput) + size;
  uint32_t FPGA_PointerV2 = FPGA_InputPointer + size*4;

  
  printf("v1[1] = %i; v2[i] = %i\n", ((uint32_t*) addrInput)[1], ((uint32_t*) addrInput)[size+1]);
  setVectorSize(addVectorConfigBase, size);
  setVectorsPointers(addVectorConfigBase, FPGA_InputPointer, FPGA_PointerV2, FPGA_ResultPointer);
  printVectorPointers(addVectorConfigBase);
  printf("size = %i\n", size);
  memcpy(addrInput, v1, size*sizeof(uint32_t)); //Copy first vector to inputRegion
  //memcpy(addrInput2, v2, size*sizeof(uint32_t)); //Copy second vector to inputRegion
  turnOnAddVector(addVectorConfigBase); //trigger
  return (uint32_t*) resultBase;
}


void feedInputs(int size, uint32_t* v1, uint32_t* v2)
{
  int i = 0;
  for (i=0; i<size; i++)
    {
      v1[i] = 3*i;
      v2[i] = i;
    }
}

uint32_t* swAddVector(uint32_t size, uint32_t* v1, uint32_t* v2)
{
	printf("HW not detected -- doing in software\n");
	uint32_t* vecResult = malloc(size*sizeof(uint32_t));
	int i = 0;
	for (i=0; i<size; i++) 
	{
		vecResult[i] = v1[i] + v2[i];
	}
	return vecResult;
}


int main(int argc, char* argv[])
{
    if (argc < 4) 
  {
	  printf("./programa vectorSize verboseMode invertHwDetection\n");
	  return 0;
  }

  uint32_t vecSize = atoi(argv[1]);
  int verbose = atoi(argv[2]);
  int forceSw = atoi(argv[3]);
  
  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  printf("fd -> %i\n", fd);
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

  uint32_t* vec1 = malloc(vecSize*sizeof(uint32_t));
  uint32_t* vec2 = malloc(vecSize*sizeof(uint32_t));
  uint32_t* vecResult;

  feedInputs(vecSize, vec1, vec2);
  
  int hw = checkAddVectorHardware(fd);
  if (forceSw) hw = 0;
  printf("HW: %i\n", hw);
  if (hw) vecResult = hwAddVector(vecSize, vec1, vec2, fd, 0x38000000, 0x38C00000);
  else vecResult = swAddVector(vecSize, vec1, vec2);

  void* debug = mmap(NULL,vecSize,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,0x38000000);
  uint32_t* var = (uint32_t*) debug;
  if (atoi(argv[2]))
    {

      printf("CONFIG: %x -- %i\n", var[0], vecSize); 
      int i = 0;
      for (i=0; i < vecSize; i++)
	printf("vecResult[%i] = %i   -- vec[%i] = %i\n", i,vecResult[i],i,var[i]);
    }
  free(vec1);
  free(vec2);
  //free(vecResult);  
}
