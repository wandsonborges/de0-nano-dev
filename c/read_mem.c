#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

#define FRAME_ADDR 0x38000000
#define FRAME_SPAN 0x500000

void* frame_base;

int main(){
	FILE* fout;


	int fd = open("/dev/mem", (O_RDWR|O_SYNC));


	frame_base = mmap(NULL,FRAME_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,FRAME_ADDR);
	
//while(1)
//{
	fout = fopen("/tmp/image.bin", "w+b");
	if (fout != NULL)
	{
		fwrite(frame_base, 1, 2592*1944, fout);
        	fclose(fout);
	}
//}

	//int i = 0;
	//char pxl;
	
	//for (i=0;i<2592*1944;i++) {
	//pxl=*(char *)(frame_base + i);
	//printf("%d\n", pxl);
	//}
}


