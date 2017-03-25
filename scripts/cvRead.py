import numpy as np
import cv2


while True:
    np_pxls = np.fromfile("/tmp/image.bin", dtype=np.uint8, count=-1, sep="")

    #with open("/tmp/image.bin", "rb") as f:
    #pxls = f.read()
    #while byte:
     #   pxls.append(byte)
     #print len(pxls)
     #np_pxls = np.array(pxls, dtype=np.uint8)
    np_pxls.resize(1944, 2592)
    np_pxls_bayer = cv2.cvtColor(np_pxls, cv2.COLOR_BayerBG2BGR)
    cv2.imshow("display1", cv2.resize(np_pxls_bayer, (0,0), fx=0.5, fy=0.5))
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
