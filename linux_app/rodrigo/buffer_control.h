#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>


#define FRAME_ADDR 0xFF210000
#define FRAME_SPAN 0x10

#define REG_ADDR_OFFSET 0
#define REG_REQBUFFER_OFFSET 1 

void* frame_base;

void requestBuffer(void* mem)
{
	*((int*)(mem) + REG_REQBUFFER_OFFSET) = 1;	
}

void freeBuffer(void* mem)
{
	*((int*)(mem) + REG_REQBUFFER_OFFSET) = 0;
}

int getBufferAddr(void* mem)
{
	int buffer_addr = *(int*) (mem + REG_ADDR_OFFSET);
	return buffer_addr;
}

int checkBufferStatus(void* mem) //1 - livre ; 0 - busy
{
	int status = *((int*)(mem) + REG_REQBUFFER_OFFSET);
	if (status) printf("***Buffer Status : BUFFER FREE\n");
	else printf("***Buffer Status: BUFFER LOCKED\n");
	return status;
}

int getBufferAddrControl(void* mem)
{
	int buf_addr;

	requestBuffer(mem);
	buf_addr = getBufferAddr(mem);
	freeBuffer(mem);
	
}
	


