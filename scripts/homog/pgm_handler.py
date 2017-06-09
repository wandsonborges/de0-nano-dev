import math
import numpy as np


def get_num_lin(matriz):
    return matriz.shape[0]

def get_num_cols(matriz):
    return matriz.shape[1]

#n pode ter comentarios!
def imgpgm_to_matrix (img, w, h):
    img_pixels = []
    for i in range(3):
        img.readline()
    for line in img:
        line_split = line.split()
        img_pixels.append(line_split)
    mat_pixels = np.array(img_pixels, dtype=int)
    mat_pixels.resize(h,w)
    return mat_pixels

def write_pgm (matriz_pix, arq):
    linhas = get_num_lin(matriz_pix)
    colunas = get_num_cols(matriz_pix)
    arq.write("P2 \n" + str(colunas) + " " + str(linhas) + "\n255\n")
    for linha in range(linhas):
       for coluna in range(colunas):
          arq.write(str(matriz_pix[linha][coluna]) + " ")
       arq.write("\n")
