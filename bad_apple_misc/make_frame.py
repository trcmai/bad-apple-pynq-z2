import subprocess
import numpy as np
import os

raw = np.fromfile("gray_160x120.raw",dtype = np.uint8)
W = 160
H = 120
frames = raw.reshape(-1,W*H)
bits = (frames > 127).astype(np.uint8)
packed = np.packbits(bits, axis=1, bitorder="little")
print(packed.shape)

words = packed.view("<u4")
print(words.shape, words.dtype)  
np.save("badapple_160x120.npy", words)
