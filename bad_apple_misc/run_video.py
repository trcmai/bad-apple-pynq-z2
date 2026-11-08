from pynq import Overlay, MMIO, allocate
import numpy as np
import time

GPIO_OUT_BASE = 0x4120_0000   # ch1 = i_base_addr, ch2 = i_start
GPIO_IN_BASE  = 0x4121_0000   # ch1 = {o_err, o_done}
GPIO_DATA  = 0x00
GPIO2_DATA = 0x08

WORDS_PER_FRAME = 600
PADDED_WORDS    = 608
FRAME_STRIDE    = PADDED_WORDS * 4
FPS = 30

ol = Overlay("bad_apple.bit")
gpio_out = MMIO(GPIO_OUT_BASE, 0x10)
gpio_in  = MMIO(GPIO_IN_BASE, 0x10)

frames = np.load("badapple_160x120.npy")
padded = np.zeros((len(frames), PADDED_WORDS), dtype=np.uint32)
padded[:, :WORDS_PER_FRAME] = frames

buf = allocate(shape=padded.shape, dtype=np.uint32)
buf[:] = padded
buf.flush()
base = buf.physical_address

def fetch(i, timeout=0.1):
    gpio_out.write(GPIO_DATA, base + i * FRAME_STRIDE)
    gpio_out.write(GPIO2_DATA, 1)
    gpio_out.write(GPIO2_DATA, 0)

    t = time.perf_counter()
    while True:
        status = gpio_in.read(GPIO_DATA)
        if status & 0b01:
            break
        if time.perf_counter() - t > timeout:
            raise RuntimeError("frame %d: o_done never came" % i)
    if status & 0b10:
        raise RuntimeError("frame %d: AXI read error" % i)

fetch(4500)
input("frame 4500 fetched, check the monitor, press Enter to play")

t0 = time.perf_counter()
for i in range(len(frames)):
    fetch(i)
    wait = t0 + (i + 1) / FPS - time.perf_counter()
    if wait > 0:
        time.sleep(wait)
print("done in", round(time.perf_counter() - t0, 1), "s  (video is 219 s)")

buf.freebuffer()