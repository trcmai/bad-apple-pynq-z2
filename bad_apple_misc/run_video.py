from pynq import Overlay, MMIO
import numpy as np
import time

ol = Overlay("bad_apple.bit")
bram = MMIO(0x40000000, 8192)
frames = np.load("badapple_160x120.npy")
print(frames.shape, frames.dtype)

fps = 30
t0 = time.perf_counter()
for i in range(len(frames)):
    bram.array[0:600] = frames[i]
    wait = t0 + (i + 1) / fps - time.perf_counter()
    if wait > 0:
        time.sleep(wait)
print("done in", round(time.perf_counter() - t0, 1), "s  (video is 219 s)")