#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>
#define SERVER_PORT 13000
#define MAX_PENDING 5
#define MAX_LINE 256
#include <errno.h>

#define IMG_TYPE uint8_t
#define NPIXELS_DEC 720*624
#define NPIXELS 1944*2592

#define NPIXELS2 NPIXELS + ((512 - (NPIXELS % 512)) % 512)

#define IMG_SIZE NPIXELS2*sizeof(IMG_TYPE)

int main()
{
  struct sockaddr_in sin;
  char buf[MAX_LINE];  
  socklen_t len;
  int s, new_s, n;
  uint8_t init_resp = 0x8B;
  int ret=0;
  //char teste[5] = "abcd"; 
  /* build address data structure */
  bzero((char *)&sin, sizeof(sin));
  sin.sin_family = AF_INET;
  sin.sin_addr.s_addr = INADDR_ANY;
  sin.sin_port = htons(SERVER_PORT);
 
  /* setup passive open */
  if ((s = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
    perror("socket");
    exit(1);
  }
  printf("socket ok\n");
  if ((bind(s, (struct sockaddr *)&sin, sizeof(sin))) < 0) {
    perror("bind");
    exit(1);
  }
  printf("bind ok\n");
  listen(s, MAX_PENDING);
  len = sizeof(sin);
  /* wait for connection, then receive and print text */
  while(1) {
    if ((new_s = accept(s, (struct sockaddr *)&sin, &len)) < 0) {
      perror("accept");
      exit(1);
    }
    printf("accept ok\n");
    ret=send(new_s, &init_resp, sizeof(init_resp),0);
    if(ret == -1) {  
      perror("Erro ao enviar");
      printf("%d\n", errno);
      exit(1);
    }
    

    recv(new_s, buf, sizeof(buf), 0);    
    printf("rec: %x\n", buf[0]);   
    uint8_t version[6] = {0xF1, 0x6A, 0x03, 0xF2, 0xF3, 0xF4};    
    send(new_s, version, sizeof(version), 0);    

    uint8_t ack = 0x07;
    uint8_t *img = malloc(IMG_SIZE);
    memset(img, 0x7f, IMG_SIZE);

    uint8_t regAddr[2];
    uint8_t regmap[4] = {0x0A, 0x20, 0x07, 0x98 };
    int count = 0;

    int nImg = 300;
    int countImg = 0;
    while(countImg < nImg) {
      recv(new_s, buf, sizeof(buf), 0);
      printf("rec req: %x\n", buf[0]);
      if (buf[0] == 0x01)
	{
	printf("img req\n");
	send(new_s, &ack, 1, 0);
	send(new_s, img, IMG_SIZE,0);
	countImg++;
	}
      else if (buf[0] == 0x65)
	{
          send(new_s, &ack, 1, 0);
	  send(new_s, &regmap[count], sizeof(regmap[count]),0);
	  printf("register req4 %x -- count = %i\n", regmap[count], count );
	  if (count == 3) count = 0;
	  else count++;
	}
      else if (buf[0] == 0x60)
	{
          send(new_s, &ack, 1, 0);
	  printf("register write\n");
	}
      else if (buf[0] == 0x55)
	{
	  printf("setBuffersize\n");
	  send(new_s, &ack, 1, 0);
	}
      else
	{
	  send(new_s, &ack, 1, 0);
	}
    }
	 
    free(img);
    close(new_s);
  }
}
