#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include "hwlib.h"
#include "../qsys_headers/hps_0.h"


#define LW_AXI_BASE 0xFF200000 //ARM LW ADDR BASE
#define LW_AXI_SPAN 0x00200000 //2 MB SIZE

#define H2F_AXI_BASE 0xC0000000
#define H2F_AXI_SPAN 0x80000


void* h2f_axi_base;
void* virtual_base;
void* reserved_base;
void* led_addr;
void* sw_addr;

int fd;
int switches;

uint32_t mem_value;
uint32_t axi_value;

int i;

int main (){
  fd=open("/dev/mem",(O_RDWR|O_SYNC));


  //Creating pointer do LWAXI bus
  virtual_base = mmap(NULL,LW_AXI_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,LW_AXI_BASE);
  h2f_axi_base = mmap(NULL,H2F_AXI_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,H2F_AXI_BASE);

  sw_addr = h2f_axi_base + SW_BASE; //defined in hps_0.h
  led_addr = h2f_axi_base + LED_BASE; //defined in hps_0.h

  
  while(1){
    switches=*(uint32_t *)sw_addr;
    *(uint32_t *)led_addr=switches;
    usleep(1000000);
    printf("SW_value :%u\n",switches);
  }

return 0;
}
