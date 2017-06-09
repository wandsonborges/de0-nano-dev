import cv2
import numpy as np
import socket
import sys
from time import sleep

def recvall(sock, n):
    # Helper function to recv n bytes or return None if EOF is hit
    data = ''
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data += packet
    return data

def processImgD5M(img):    
    img = cv2.cvtColor(img, cv2.COLOR_BayerBG2BGR)
    img = cv2.resize(img, (COLS/2, LINES/2))
    return img


def processImgD5MHomog(img):    
    #img = cv2.cvtColor(img, cv2.COLOR_BayerBG2BGR)
    img = cv2.resize(img, (COLS/2, LINES/2))
    return img


COLS = int(sys.argv[1]) #2592#640
LINES = int(sys.argv[2]) #1944#480 #1944
NPIXELS = COLS*LINES;
FRAME_SIZE = NPIXELS + ((512 - (NPIXELS % 512)) % 512)

fsize = FRAME_SIZE

client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client_socket.connect(('192.168.1.13', 13000))

keyPressed = -1

my_bytes = bytearray()
my_bytes.append(1)
data = client_socket.recv(512)
if (ord(data) == 139):
    print("conectou")
    client_socket.send("a");
    version = client_socket.recv(512)
    print(version);
    while (keyPressed != ord('q')):
           #client_socket.send(my_bytes);
           #ack = client_socket.recv(8);
           img_array = np.fromstring(recvall(client_socket, FRAME_SIZE), dtype='uint8')
           img_array.resize(LINES,COLS)
           print("rec img")
           #cv2.imshow("Display", img_array)
           cv2.imshow("Display", processImgD5MHomog(img_array))
           keyPressed = cv2.waitKey(1)

            
        
        
        
  
