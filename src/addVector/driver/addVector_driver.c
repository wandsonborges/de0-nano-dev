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

#define ADDR_READ_BASE 0x38000000
#define ADDR_SPAN 0x4000000
#define ADDR_WRITE_BASE 0x38C00000

#define SIGNATURE 0x11223344

#define FIRE_REG_OFFSET 2
#define VEC_SIZE_REG_OFFSET 1

void* addVectorConfigBase; 
void* readBase;
void* resultBase;

uint32_t* getRegisters(void* mem)
{
  uint32_t *addVectorConfigRegs = (uint32_t*) (mem);
        return addVectorConfigRegs;
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

void setVector1(void* mem, void* config, uint32_t* vector)
{
	int size = getVectorSize(config);
	printf("got vec size: %i\n", size);
	int i = 0;
	for (i=0; i<size; i++) 
	{
		*((uint32_t*)(mem) + i) = vector[i]; 		
	}

}

void setVector2(void* mem, void* config, uint32_t* vector)
{
	int size = getVectorSize(config);
	int i = 0;
	for (i=0;i<size;i++)
	{
		*((uint32_t*)(mem) + size + i) = vector[i];
	}
}

int checkAddVectorHardware(void* mem)
{
	uint32_t* regs = getRegisters(mem);
	if (regs[0] == SIGNATURE) return 1;
	else return 0;
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

uint32_t* hwAddVector(uint32_t size, uint32_t* v1, uint32_t* v2, void* configMem, void* inputMem, void* outputMem)
{
  printf("Hardware detected\n");
  uint32_t* addr_v2 = (uint32_t*) (inputMem) + size; // Pointer to second parameter
  setVectorSize(configMem, size); 
  printf("size = %i\n", size);
  memcpy(inputMem, v1, size*sizeof(uint32_t)); //Copy first vector to inputRegion
  memcpy(addr_v2, v2, size*sizeof(uint32_t)); //Copy second vector to inputRegion
  turnOnAddVector(configMem); //trigger
  return (uint32_t*) outputMem;
}

int main(int argc, char* argv[]){
  FILE* fout;

  if (argc < 4) 
  {
	  printf("./programa vectorSize verboseMode invertHwDetection\n");
	  return 0;
  }
  int fd = open("/dev/mem", (O_RDWR|O_SYNC));
  if (fd == -1) {
	perror("Error opening file for writing");
	exit(EXIT_FAILURE);
    }

  addVectorConfigBase = mmap(NULL,LW_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_ADDR_BASE) + ADD_VECTOR_CONFIG_OFFSET;
  readBase = mmap(NULL,ADDR_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,ADDR_READ_BASE);
  resultBase = mmap(NULL,ADDR_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,ADDR_WRITE_BASE);

  if (addVectorConfigBase == MAP_FAILED || readBase == MAP_FAILED || resultBase == MAP_FAILED) {
	close(fd);
	perror("Error mmapping the file");
	exit(EXIT_FAILURE);
    }
  
 
  uint32_t vecSize = atoi(argv[1]);
  
  uint32_t* vec1 = malloc(vecSize*sizeof(uint32_t));
  uint32_t* vec2 = malloc(vecSize*sizeof(uint32_t));
  uint32_t* vecResult;

  //Populate inputs
  int i = 0;
  for (i=0; i < vecSize; i++)
  {
	  vec1[i] = i*2;
	  vec2[i] = i;
  }

  int invertDetect = atoi(argv[3]);
  int hw = checkAddVectorHardware(addVectorConfigBase);
  if (invertDetect) hw = 0;
  printf("HW: %i\n", hw);
  if (hw) vecResult = hwAddVector(vecSize, vec1, vec2, addVectorConfigBase, readBase, resultBase);
  else vecResult = swAddVector(vecSize, vec1, vec2);

  uint32_t* var = (uint32_t*)readBase;
  uint32_t* res = (uint32_t*)addVectorConfigBase;
  i = 0;

  if (atoi(argv[2]))
  {

  printf("CONFIG: %x -- %i\n", var[0], vecSize); 
  i = 0;
  for (i=0; i < vecSize; i++)
    printf("vecResult[%i] = %i   -- vec[%i] = %i\n", i,vecResult[i],i,var[i]);
  }
  free(vec1);
  free(vec2);
}
