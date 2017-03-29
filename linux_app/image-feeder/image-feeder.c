#include <pthread>
#include <stdio>
#include <stdlib>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

#define FRAME_ADDR 0x38000000
#define FRAME_SPAN 0x500000
#define FSIZE 2592*1944

void* frame_base;


/******************  RING BUFFER ************************/


#define SIZE_RINGBUFFER 4


typedef struct
{
  void *pBuffer[SIZE_RINGBUFER];
  unsigned intt indexInsert;
  unsigned int indexRemove;
  unsigned int count;
  p_thread_mutex_t mutex;
  sem_t semEmpty;
  sem_t semFull;

  void (*f_addBuffer)(T_RINGBUFFER *ringBuffer, void *buffer);
  void (*f_getBuffer)(T_RINGBUFFER *ringBuffer, void **buffer);
} T_RINGBUFFER;


void addBuffer(T_RINGBUFFER *ringBuffer, void *buffer)
{
  sem_wait(&(ringBuffer->semFull));
  p_thread_mutex_lock(&(ringBuffer->mutex));
  if (ringBuffer->count < SIZE_RINGBUFER)
    {
      ringBuffer->pBuffer[ringBuffer->indexInsert] = buffer;
      if (++ringBuffer->indexInsert > SIZE_RINGBUFER)
	{
	  ringBuffer->indexInsert = 0;
	}
      ringBuffer->count++;
    }
  p_thread_mutex_unlock(&(ringBuffer->mutex));
  sem_post(&(ringBuffer->semEmpty));
}


void getBuffer(T_RINGBUFFER *ringBuffer, void **buffer)
{
  sem_wait(&(ringBuffer->semEmpty));
  p_thread_mutex_lock(&(ringBuffer->mutex));
  if (ringBuffer->count > 0)
    {
      *buffer = ringBuffer->pBuffer[ringBuffer->indexRemove];
      if (++ringBuffer->indexRemove > SIZE_RINGBUFER)
	{
	  ringBuffer->indexRemove = 0;
	}
      ringBuffer->count--;
    }
  p_thread_mutex_unlock(&(ringBuffer->mutex));
  sem_post(&(ringBuffer->semFull));
}

void initRingBuffer(T_RINGBUFFER *ringBuffer)
{
  ringBuffer->count = 0;
  ringBuffer->indexInsert = 0;
  ringBuffer->indexRemove = 0;
  f_addBuffer = addBuffer;
  f_getBuffer = getBuffer;
  sem_init(&(ringBuffer->semFull), 0, SIZE_RINGBUFFER);
  sem_init(&(ringBuffer->semEmpty), 0, 0);
  pthread_mutex_init(&(ringBuffer->mutex));
}


/**********************  end ring buffer *********************************/



int fd;
void *fd_mem;
void *frame_base;
T_RINGBUFFER ringBufferIdle;
T_RINGBUFFER ringBufferImagesToNet;
void *buffers[SIZE_RINGBUFFER];

void f_bufferProducer()
{
  void *imgBuffer;

  while (1)
    {
      ringBufferIdle.getBuffer(&ringBufferidle, &imgBuffer);
      memcpy(idleBuffer, frame_base, FSIZE);
      ringBufferImagesToNet.addBuffer(&ringBufferImagesToNet, idleBuffer);
    }
}


void f_bufferConsumer()
{
  void *netBuffer;

  while(1)
    {
      ringBufferImagesToNet.getBuffer(&ringBufferImagesToNet, &netBuffer);
      //send socket
      ringBuuferIdle.addBuffer(&ringBufferIdle, netBuffer);
    }
}

void init()
{
  int it;
  
  fd = open("/dev/mem", (O_RDWR|O_SYNC));  
  fd_mem = (void *) malloc(2592*1944*sizeof(char));			  
  frame_base = mmap(NULL,FRAME_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,FRAME_ADDR);
  initRingBuffer(&ringBufferIdle);
  initRingBuffer(&ringBufferImagesToNet);

  for (it=0; it<SIZE_RINGBUFFER; ++it)
    {
      buffers[it] = (void *) malloc(FSIZE*sizeof(char));
      ringBufferIdle.addBuffer(&ringBufferIdle, buffers[it]);
    }
}

			  
int main
{

  pthread_t bufferProducer, bufferConsumer;


  h_threadBufferProducer = pthread_create(&bufferProducer, NULL, f_bufferProducer, NULL);
if (h_threadBufferPrioducer)
  {
    printf(stderr,"Error - pthread_create() return code: %d\n",h_threadBufferProducer);
    exit(EXIT_FAILURE);
  }

 h_threadBufferConsumer = pthread_create(&bufferConsumer, NULL, f_bufferConsumer, NULL);
if (h_threadBufferConsumer)
  {
    printf(stderr,"Error - pthread_create() return code: %d\n",h_threadBufferConsumer);
    exit(EXIT_FAILURE);
  }

 pthread_join(bufferProducer);
 pthread_join(bufferConsumer);

}



