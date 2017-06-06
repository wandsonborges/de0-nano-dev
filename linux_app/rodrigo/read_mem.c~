#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

#define FRAME_ADDR 0x38000000
#define FRAME_SPAN 0x500000
#define FSIZE 2592*1944

void* frame_base;

int main(){
	int i=0;
	FILE* fout;


	int fd = open("/dev/mem", (O_RDWR|O_SYNC));
	FILE * fd_ti = fopen("/tmp/img.bin", "rb");
	void *fd_mem=(void *) malloc(2592*1944*sizeof(char));


	frame_base = mmap(NULL,FRAME_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,FRAME_ADDR);
	
//while(1)
//{
	//fout = fopen("/tmp/image.bin", "w+b");
	//if (fout != NULL)
	//{
	//fread(fd_mem, 1, 2592*1944, fd_ti);
	for(i=0;i<7;i++)
	{
		memcpy(fd_mem, frame_base, FSIZE); 
		fwrite(fd_mem, 1, 2592*1944, stdout);
		//write(1, frame_base, 2592*1944);
        	//fclose(fout);
	}
	//}
//}

	//int i = 0;
	//char pxl;
	
	//for (i=0;i<2592*1944;i++) {
	//pxl=*(char *)(frame_base + i);
	//printf("%d\n", pxl);
	//}
}


