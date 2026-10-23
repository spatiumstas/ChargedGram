from pathlib import Path
import ctypes
import gzip
import sys

root = Path(__file__).resolve().parents[3]
lib = ctypes.CDLL(sys.argv[1])
lib.lottie_animation_from_data.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.lottie_animation_from_data.restype = ctypes.c_void_p
lib.lottie_animation_render.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint32), ctypes.c_size_t, ctypes.c_size_t, ctypes.c_size_t]
lib.lottie_animation_destroy.argtypes = [ctypes.c_void_p]
source = gzip.decompress((root / "Resources/tgs/duck_empty.tgs").read_bytes())
animation = lib.lottie_animation_from_data(source, b"duck_empty_preview", b"")
assert animation
pixels = (ctypes.c_uint32 * (240 * 240))()
lib.lottie_animation_render(animation, 20, pixels, 240, 240, 960)
Path(sys.argv[2]).write_bytes(bytes(pixels))
lib.lottie_animation_destroy(animation)
