import numpy as np

W, H = 480, 360
WORDS = W * H // 32          # 5400
PADDED = 5408                # 338 bursts x 16 words

raw = np.memmap("gray_480x360.raw", dtype=np.uint8, mode="r").reshape(-1, W * H)
print("frames:", raw.shape[0])

bits   = (raw > 127).astype(np.uint8)
packed = np.packbits(bits, axis=1, bitorder="little")   # same bit order as before
words  = packed.view("<u4")                              # (N, 5400)

out = np.zeros((words.shape[0], PADDED), dtype=np.uint32)
out[:, :WORDS] = words
np.save("badapple_480x360.npy", out)
print("saved", out.shape, out.nbytes / 1e6, "MB")