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
afi0 = MMIO(0xF8008000, 0x20)            # HP0 AFI
afi0.write(0x00, afi0.read(0x00) | 1)    # HP0 reads: 32-bit mode
gpio_out = MMIO(GPIO_OUT_BASE, 0x10)
gpio_in  = MMIO(GPIO_IN_BASE, 0x10)


frames = np.load("badapple_480x360.npy", mmap_mode="r")   # (6572, 5408), read on demand
FRAME_STRIDE = 5408 * 4
SLOTS = 2

buf = allocate(shape=(SLOTS, 5408), dtype=np.uint32)      # ~43 KB, always fits
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

def show(i, timeout=0.1):
    s = i % SLOTS
    buf[s] = frames[i]          # copy frame i into a slot
    buf.flush()                 # CPU cache -> DDR
    fetch(s)                    # fetcher reads slot s

t0 = time.perf_counter()
for i in range(len(frames)):
    show(i)
    wait = t0 + (i + 1) / FPS - time.perf_counter()
    if wait > 0:
        time.sleep(wait)
print("done in", round(time.perf_counter() - t0, 1), "s  (video is 219 s)")
buf.freebuffer()