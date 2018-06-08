import sys
import cv2
import numpy as np

img_in = cv2.imread(sys.argv[1], cv2.IMREAD_GRAYSCALE)
cv2.imshow("teste", img_in)

lines = len(img_in)-2
cols = len(img_in[0])-2
img_out = np.zeros((lines, cols,1), np.uint8)

for i in range(0, lines):
    for j in range(0, cols):
        img_out[i][j] = img_in[i+1][j+1]
        print(int(img_out[i][j]))        
#cv2.imshow("out", img_out)
#cv2.waitKey()
                    
