#!/usr/bin/env python3
"""Print the cache key for a named reference hardware profile (used by cache workflow)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "zeros_py"))
from zeros import detect
PROFILES = {
    "generic":   detect.Profile(march="x86-64", cpu_flags=["mmx","sse","sse2"], video_cards=["fbdev"]),
    "x86-64-v3": detect.Profile(march="x86-64-v3", cpu_flags=["avx","avx2","fma","sse4_2"], video_cards=["fbdev"]),
    "znver3":    detect.Profile(march="znver3", cpu_flags=["avx","avx2","fma","sse4_2","aes"], video_cards=["amdgpu","radeonsi"]),
    "skylake":   detect.Profile(march="skylake", cpu_flags=["avx","avx2","fma","sse4_2","aes"], video_cards=["intel"]),
}
p = PROFILES[sys.argv[1]]
print(p.cache_key())
