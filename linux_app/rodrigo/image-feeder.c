
#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#define SERVER_PORT 13000


#define LW_AXI_BASE 0xFF200000 //ARM LW ADDR BASE
#define LW_AXI_SPAN 0x00200000 //2 MB SIZE
#define FPGA_FRAMEBUFFER_CONTROL_ADDRBASE  (0x10000)
#define F2H_AXI_BASE 0xC0000000
#define F2H_AXI_SPAN 0x80000

#define FPGA_FRAMEBUFFER_REG_READIMAGEADDR 0
#define FPGA_FRAMEBUFFER_REG_CONTROLSTATUS 1
#define FPGA_FRAMEBUFFER_CONTROL_BIT_REQ_READBUFFER 1
#define FPGA_FRAMEBUFFER_CONTROL_BIT_STATUS_READBUFFERAVAILABLE 2

#define FPGA_FRAME0_ADDR 0x38000000
#define FPGA_FRAME1_ADDR 0x38500000
#define FRAME_SPAN 0x500000
#define FRAME_SIZE 2592*1944

#define REG_ADDR_OFFSET 0
#define REG_REQBUFFER_OFFSET 1 

#define MAX_PENDING 5

void* frame_base;





/******************  RING BUFFER ************************/


#define SIZE_RINGBUFFER 5

struct RINGBUFFER;


typedef struct RINGBUFFER
{
  void *pBuffer[SIZE_RINGBUFFER];
  unsigned int indexInsert;
  unsigned int indexRemove;
  unsigned int count;
  pthread_mutex_t mutex;
  sem_t semEmpty;
  sem_t semFull;

  void (*f_addBuffer)(struct RINGBUFFER *ringBuffer, void *buffer);
  void (*f_getBuffer)(struct RINGBUFFER *ringBuffer, void **buffer);
} T_RINGBUFFER;


void addBuffer(T_RINGBUFFER *ringBuffer, void *buffer)
{
  sem_wait(&(ringBuffer->semFull));
  pthread_mutex_lock(&(ringBuffer->mutex));
  if (ringBuffer->count < SIZE_RINGBUFFER)
    {
      ringBuffer->pBuffer[ringBuffer->indexInsert] = buffer;
      if (++(ringBuffer->indexInsert) >= SIZE_RINGBUFFER)
	{
	  ringBuffer->indexInsert = 0;
	}
      ringBuffer->count++;
    }
  //printf("added buffer %x at position %d. New count: %d\n", (unsigned int)buffer, ringBuffer->indexInsert, ringBuffer->count);
  pthread_mutex_unlock(&(ringBuffer->mutex));
  sem_post(&(ringBuffer->semEmpty));
}


void getBuffer(T_RINGBUFFER *ringBuffer, void **buffer)
{
  sem_wait(&(ringBuffer->semEmpty));
  pthread_mutex_lock(&(ringBuffer->mutex));
  if (ringBuffer->count > 0)
    {
      *buffer = ringBuffer->pBuffer[ringBuffer->indexRemove];
      if (++(ringBuffer->indexRemove) >= SIZE_RINGBUFFER)
	{
	  ringBuffer->indexRemove = 0;
	}
      ringBuffer->count--;
    }
  else
    {
      *buffer = NULL;
    }
  //printf("retrieved buffer %x from position %d. New count: %d\n", (unsigned int)*buffer, ringBuffer->indexRemove, ringBuffer->count);
  pthread_mutex_unlock(&(ringBuffer->mutex));
  sem_post(&(ringBuffer->semFull));
}

void initRingBuffer(T_RINGBUFFER *ringBuffer)
{
  ringBuffer->count = 0;
  ringBuffer->indexInsert = 0;
  ringBuffer->indexRemove = 0;
  ringBuffer->f_addBuffer = addBuffer;
  ringBuffer->f_getBuffer = getBuffer;
  sem_init(&(ringBuffer->semFull), 0, SIZE_RINGBUFFER);
  sem_init(&(ringBuffer->semEmpty), 0, 0);
  pthread_mutex_init(&(ringBuffer->mutex), NULL);
}


/**********************  end ring buffer *********************************/


/******BUFFER CONTROL FUNCTIONS**********/
void requestBuffer(void* mem)
{
	*((int*)(mem) + REG_REQBUFFER_OFFSET) = 1;	
}

void freeBuffer(void* mem)
{
	*((int*)(mem) + REG_REQBUFFER_OFFSET) = 0;
}

uint32_t getBufferAddr(void* mem)
{
	uint32_t buffer_addr = *(int*) (mem + REG_ADDR_OFFSET);
	return buffer_addr;
}

uint32_t* getBufferPointer(void* mem)
{
  uint32_t* pointer = (uint32_t*) getBufferAddr(mem);
  return pointer;
}    


/************************Global Variables*****************************/
static int fd;
static void *fd_mem;
static T_RINGBUFFER ringBufferIdle;
static T_RINGBUFFER ringBufferImagesToNet;
static void *buffers[SIZE_RINGBUFFER];
static int errOk;

static int fpga_lwfd;
static void *fpga_lw_base;
static void *fpga_frameBufferControl_baseAddr;

static void *fpgaFrameBuffer[2];



struct hostent *hp;
struct sockaddr_in socket_in;
socklen_t len;
int int_socket;







void initSocket()
{
  printf("Iniciando conexao\n");
  //printf("Host ok\n"); 
  /* build address data structure */
  bzero((char *)&socket_in, sizeof(socket_in));
  socket_in.sin_family = AF_INET;
  socket_in.sin_addr.s_addr = INADDR_ANY;
  socket_in.sin_port = htons(SERVER_PORT);
  
  /* active open */
  if ((int_socket = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
    perror("socket: socket error");
    exit(1);
  }
  printf("SOCKET ok\n");
  if ((bind(int_socket, (struct sockaddr *)&socket_in, sizeof(socket_in))) < 0) {
    perror("bind");
    exit(1);
  }
  printf("bind ok\n");
    
 listen(int_socket, MAX_PENDING); 
  len = sizeof(socket_in);
  printf("Connection ok\n");    
}




/* static void* getFpgaFrameBuffer() */
/* { */
  
/*   /\* printf("debug before bla\n"); *\/ */
/*   /\* *((uint32_t*)fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_CONTROLSTATUS) |= FPGA_FRAMEBUFFER_CONTROL_BIT_REQ_READBUFFER; *\/ */
/*   /\* printf("debug\n"); *\/ */
/*   /\* printf("lw addr reg value: %x\n", *((uint32_t*)fpga_frameBufferControl_baseAddr)); *\/ */
/*   /\* printf("lw control reg value: %x\n", *((uint32_t*)fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_CONTROLSTATUS)); *\/ */
/*   //printf("lw control reg: %x\n", (uint32_t)(uint32_t*)(fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_CONTROLSTATUS)); */
/*   //printf("lw control bit: %x\n", (uint32_t)FPGA_FRAMEBUFFER_CONTROL_BIT_REQ_READBUFFER); */
/*   //printf("lw control bit: %x\n", (uint32_t)FPGA_FRAMEBUFFER_CONTROL_BIT_STATUS_READBUFFERAVAILABLE); */
	 
/*   //while ( !( *((uint32_t*)fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_CONTROLSTATUS) & FPGA_FRAMEBUFFER_CONTROL_BIT_STATUS_READBUFFERAVAILABLE ) ); */
/*   //return fpgaFrameBuffer[*((uint32_t*)fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_READIMAGEADDR)]; */
/* } */

static endBufferRead()
{
  *((uint32_t*)fpga_frameBufferControl_baseAddr + FPGA_FRAMEBUFFER_REG_CONTROLSTATUS) &= ~FPGA_FRAMEBUFFER_CONTROL_BIT_REQ_READBUFFER;
}


static void f_bufferProducer()
{
  void *imgBuffer, *fpgaFrame;

  while (errOk)
    {
      ringBufferIdle.f_getBuffer(&ringBufferIdle, &imgBuffer);
      if (imgBuffer == NULL)
	{
	  errOk = 0;
	}
      else
	{
	  printf("prod 1\n");
	  //requestBuffer(fpga_frameBufferControl_baseAddr); printf("prod 2\n");
	  fpgaFrame = fpgaFrameBuffer[0] ; printf("prod 3 -- Frame Pointer:%x\n", fpgaFrame);
	  memcpy(imgBuffer, fpgaFrame, FRAME_SIZE);  printf("prod 4\n");
	  //freeBuffer(fpga_frameBufferControl_baseAddr); 	  printf("prod 5\n");
	  ringBufferImagesToNet.f_addBuffer(&ringBufferImagesToNet, imgBuffer); 	  printf("prod 6\n");
	}
      //printf("P: buffer %x added to net ring\n", (unsigned int)imgBuffer);
    }
}


static void f_bufferConsumer()
{
  void *netBuffer;

  while(errOk)
    {
      ringBufferImagesToNet.f_getBuffer(&ringBufferImagesToNet, &netBuffer);
      //////printf("C: buffer %x retrieved from net ring\n", (unsigned int)netBuffer);
      if (send(int_socket, netBuffer, FRAME_SIZE, 0) < 0)
	{
	  printf("error sending data ...\n");
	  errOk = 0;
	}
      else
	{
	  //printf("image sent\n");
	  ringBufferIdle.f_addBuffer(&ringBufferIdle, netBuffer);
	}
      //////printf("C: buffer %x returned to idle ring\n", (unsigned int)netBuffer);
    }
}

void init()
{
  int it;
  
  fd = open("/dev/mem", (O_RDWR|O_SYNC));
  fpgaFrameBuffer[0] = mmap(NULL, FRAME_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, FPGA_FRAME0_ADDR);
  fpgaFrameBuffer[1] = mmap(NULL, FRAME_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, FPGA_FRAME1_ADDR);

  printf("debug before\n");
  fpga_lwfd = open("/dev/mem",(O_RDWR|O_SYNC));
  printf("debug before2\n");
  fpga_lw_base = mmap(NULL, F2H_AXI_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fpga_lwfd, LW_AXI_BASE);
  printf("debug before3\n");
  fpga_frameBufferControl_baseAddr = fpga_lw_base + FPGA_FRAMEBUFFER_CONTROL_ADDRBASE;
  printf("debug before4\n");

  ////printf("outside memory mapped\n");
  initRingBuffer(&ringBufferIdle);
  ////printf("created idle ring buffer\n");
  initRingBuffer(&ringBufferImagesToNet);
  ////printf("created net ring buffer\n");

  errOk = 1;
  
  for (it=0; it<SIZE_RINGBUFFER; ++it)
    {
      buffers[it] = (void *) malloc(FRAME_SIZE*sizeof(char));
      ////printf("memory allocated for buffer %d\n", it);
      ringBufferIdle.f_addBuffer(&ringBufferIdle, buffers[it]);
      ////printf ("buffer added to ring iddle\n");
    }
}


void terminate()
{
  int it;
  for (it=0; it<SIZE_RINGBUFFER; ++it)
    {
      free(buffers[it]);
    }
   close(int_socket);
   close(fd);
   close(fpga_lwfd);
}  

			  
int main(int argc, char* argv[])
{
  init();
  printf("0 -- \n");
  initSocket();
  printf("1 -- \n");
  
  pthread_t bufferProducer;
  int err;
  int new_s;
  char buf[10];

  printf("2 -- \n");
  err = pthread_create(&bufferProducer, NULL, f_bufferProducer, NULL);
  if (err)
  {
    ////printf(stderr,"Error - pthread_create() return code: %d\n",err);
    exit(EXIT_FAILURE);
  }

 /* err = pthread_create(&bufferConsumer, NULL, f_bufferConsumer, NULL); */
/* if (err) */
/*   { */
/*     ////printf(stderr,"Error - pthread_create() return code: %d\n",err); */
/*     exit(EXIT_FAILURE); */
/*   } */

  printf("3 -- \n");
  
 //pthread_join(bufferProducer, NULL);
 // pthread_join(bufferConsumer, NULL);
 printf("4 -- ");
 void *netBuffer;
 uint8_t init_resp = 0x8b;


  
 while(1) {
   if ((new_s = accept(int_socket, (struct sockaddr *)&socket_in, &len)) < 0) {
      perror("accept");
      exit(1);
    }
    printf("accept ok\n");
    send(int_socket, &init_resp, 1, 0);
    while(1) {
      recv(new_s, buf, sizeof(buf), 0);
      printf("rec req: %x\n", buf[0]);
      if (buf[0] == 0x01)
	{
	printf("img req\n");
	// SEND IMG
	ringBufferImagesToNet.f_getBuffer(&ringBufferImagesToNet, &netBuffer);
	send(int_socket, netBuffer, FRAME_SIZE, 0);
	
	}
    }
 }

    terminate();
}



