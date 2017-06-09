import numpy as np
import math
def get_num_lin(matriz):
    return matriz.shape[0]

def get_num_cols(matriz):
    return matriz.shape[1]

def get_media(matriz_pxl_1):
   v_medio = 0
   linhas = get_num_lin(matriz_pxl_1)
   cols = get_num_cols(matriz_pxl_1)
   for i in range (0, linhas):
     for j in range (0, cols):
        v_medio += matriz_pxl_1[i][j]
   return (v_medio/(linhas*cols))

def get_deviation(matrix_pxl):
   v_medio = get_media(matrix_pxl)
   linhas = get_num_lin(matrix_pxl)
   cols = get_num_cols(matrix_pxl)
   desv = 0;
   for i in range (0, linhas):
     for j in range (0, cols):
        diff_media = matrix_pxl[i][j] - v_medio
        diff_media *= diff_media
        desv += diff_media
   return (math.sqrt(desv/(linhas*cols)-1))


def get_max_min(matriz_pxl_1):
   max = matriz_pxl_1[0][0]
   min = matriz_pxl_1[0][0]
   linhas = get_num_lin(matriz_pxl_1)
   cols = get_num_cols(matriz_pxl_1)
   for i in range (0, linhas):
     for j in range (0, cols):
        if matriz_pxl_1[i][j] > max:
            max = matriz_pxl_1[i][j]
        if matriz_pxl_1[i][j] < min:
            min = matriz_pxl_1[i][j]
   return (max, min)



