import sys
import cv2
import numpy as np

cols = 640
lines = 480
img_out = np.zeros((lines, cols,1), np.uint8)
pxl = 0;
for i in range(0, lines):
    for j in range(0, cols):
        img_out[i][j] = pxl & 0xFF
        pxl = pxl + 1
        print(int(img_out[i][j]))        
#cv2.imshow("out", img_out)
#cv2.waitKey()
                    
