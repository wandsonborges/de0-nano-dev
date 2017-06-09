import sys
import numpy as np
import numpy.linalg as linalg
import copy
import decimal
import cv2
from pgm_handler import *
from matrix_handler import *
from subprocess import call


refPt = []
def get_coord(event, x, y, flags, param):
	# grab references to the global variables
	
 
	# if the left mouse button was clicked, record the starting
	# (x, y) coordinates and indicate that cropping is being
	# performed
	if event == cv2.EVENT_LBUTTONDOWN:
		refPt.append((x, y))
                

        
        



                
#fig_path_read =  "2001.pgm"
#fig_path_write = "2001_homog.pgm"
fig_path_read =  "img.pgm"
fig_path_write = "img_homog.pgm"
tcl_matrix_path = "matrix_py.txt"
tcl_script_path = "../tcl/load_homog.tcl"

img = cv2.imread(fig_path_read)
cols = 2592
rows = 1944


img_mat = open(fig_path_read, "r")
img_to_write = open(fig_path_write, "w")
tcl_matrix = open(tcl_matrix_path, "w")

img_mat = img#cv2.imread(fig_path_read, "r") #imgpgm_to_matrix(img_mat, cols, rows)

def print_vhdl(matrix):
    print "constant MATRIZ_HOMOG : matriz_homog_t := "
    print "((std_logic_vector(to_signed(" + str(matrix[0,0]) + ", MEW))," 
    print " std_logic_vector(to_signed(" + str(matrix[0,1]) + ", MEW)),"
    print " std_logic_vector(to_signed(" + str(matrix[0,2]) + ", MEW)))," 
    print"  (std_logic_vector(to_signed(" + str(matrix[1,0]) + ", MEW)),"
    print"  std_logic_vector(to_signed(" + str(matrix[1,1]) + ", MEW))," 
    print"  std_logic_vector(to_signed(" + str(matrix[1,2]) + ", MEW)))," 
    print"  (std_logic_vector(to_signed(" + str(matrix[2,0]) + ", MEW)),"
    print"   std_logic_vector(to_signed(" + str(matrix[2,1]) + ", MEW)),"
    print"   std_logic_vector(to_signed(" + str(matrix[2,2]) + ", MEW))) );"
    
def matriz_to_int_shift (matriz):
	matriz_inv_int = np.matrix( [[1,1,1],[1,1,1], [1,1,1] ], dtype=np.int64)
	for i in range(3):
		for j in range(3):
			matriz_inv_int[i,j]= np.int64(matriz[i,j]*(2**n_bits_frac_accum))
	return matriz_inv_int

matriz_teste = np.matrix([ [1,  0, 0],
                          [  0,   1,  0],
                          [  0,   0,  1]], dtype=np.float32)


matriz =  np.matrix([ [0.7,  0.7, 0],
                          [  -0.7,   0.7,  0],
                          [  0,   0,  1]], dtype=np.float32)

n_bits_frac_accum = 20
n_bits_int_accum = 12


# keep looping until the 'q' key is pressed
cv2.namedWindow("image")
cv2.setMouseCallback("image", get_coord)
while True:
	# display the image and wait for a keypress
	cv2.imshow("image", img)
	key = cv2.waitKey(1) & 0xFF
 
	# if the 'c' key is pressed, break from the loop
	if key == ord("c"):
		break
src_coord = np.array(refPt ,np.float32)
dst_coord = np.array([[0,0],[cols-1,0],[0,rows-1],[cols-1,rows-1]],np.float32)


M = cv2.getPerspectiveTransform(src_coord,dst_coord)
dst = cv2.warpPerspective(img,matriz,(cols,rows))

#cv2.imshow('img_ori', img)
cv2.imshow('img',dst)
cv2.imwrite("homog.pgm", dst)
cv2.waitKey(1)

print("Matriz homografia:")
print matriz


homog_mat = matriz
homog_inv = np.matrix(homog_mat).I
print("Matriz homografia inversa:")
print homog_inv
homog_inv_fp = matriz_to_int_shift (homog_inv)
#
#
print("Matriz homografia inversa: - FIXED POINT")
print_vhdl(homog_inv_fp)

for i in range (3):
    for j in range(3):
        if homog_inv_fp[i,j] < 0:
                b = homog_inv_fp[i,j]
                data = ((abs(b) ^ 0xffffffff) + 1) & 0xffffffff
        else:
                data = (homog_inv_fp[i,j])
        tcl_matrix.write('{0:08x}'.format(data))
        tcl_matrix.write("\n")
        print data
        print '{0:08x}'.format(data)

tcl_matrix.close()
#call(["quartus_stp", "-t", "../tcl/load_homog.tcl"])





#
# mat_to_write = []
# x_acc1 = 0
# x_acc2 = 0
# y_acc2 = 0
# y_acc1 = 0
# x_acc3 = 0
# y_acc3 = 0
# x_offset = homog_inv_fp[0,2]
# y_offset = homog_inv_fp[1,2]
# div_offset = homog_inv_fp[2,2]
# for i in range(rows):
#     for j in range(cols):
#         x_acc1 += homog_inv_fp[0,0] 
#         x_acc2 += homog_inv_fp[1,0]
#         x_acc3 += homog_inv_fp[2,0]
#         x = int((x_acc1 + y_acc1 + x_offset)/(x_acc3 + y_acc3 + div_offset))
#         y = int((x_acc2 + y_acc2 + y_offset)/(x_acc3 + y_acc3 + div_offset))
#         if (x > 0 and x < cols) and (y > 0 and y < rows):
#           #print str(j) + " " + str(i) + " ->  x: " + str(x) + " -> y: " + str(y)
#           mat_to_write.append(img_mat[y,x])
#         else:
#           #print str(j) + " " + str(i) + " ->  x: 0 y: 0"
#           mat_to_write.append(img_mat[0,0])
#     x_acc1 = 0
#     x_acc2 = 0
#     x_acc3 = 0
#     y_acc1 += homog_inv_fp[0,1]
#     y_acc2 += homog_inv_fp[1,1]
#     y_acc3 += homog_inv_fp[2,1]

# mat_pixels = np.array(mat_to_write, dtype=int)
# mat_pixels.resize(rows,cols)       
#write_pgm(mat_pixels, img_to_write)


#cv2.imshow('img',cv2.resize(dst, COLS/2, LINES/2))
cv2.waitKey(1)
cv2.destroyAllWindows()
