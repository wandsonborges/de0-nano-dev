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

int main(){
	int i=0;
	FILE* fout;


	int fd = open("/dev/mem", (O_RDWR|O_SYNC));
	frame_base = mmap(NULL,FRAME_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,FRAME_ADDR);
	
	requestBuffer(frame_base);
	checkBufferStatus(frame_base);
	int addr = getBufferAddr(frame_base);
	freeBuffer(frame_base);
	checkBufferStatus(frame_base);

	printf("BUFFER ADDR: %x\n", addr);

}


