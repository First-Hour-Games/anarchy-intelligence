import ctypes
from ctypes import wintypes
import sys

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010

kernel32 = ctypes.windll.kernel32
pid = 14708
handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)

base_addr = 0x2e3dd855000
size = 2 * 1024 * 1024 # 2MB

buf = ctypes.create_string_buffer(size)
read_bytes = ctypes.c_size_t(0)
success = kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base_addr), buf, size, ctypes.byref(read_bytes))
kernel32.CloseHandle(handle)

print(f"Read {read_bytes.value} bytes from {hex(base_addr)} (success: {bool(success)})")
data = buf.raw[:read_bytes.value]

with open("scratch/cache_region_2mb.bin", "wb") as f:
    f.write(data)

# Find all "starting_forest.tscn::" occurrences
idx = 0
found = []
prefix = b"starting_forest.tscn::"
while True:
    idx = data.find(prefix, idx)
    if idx == -1:
        break
    # Read string until null or non-ascii
    end = idx + len(prefix)
    while end < len(data) and 32 <= data[end] <= 126:
        end += 1
    found.append((idx, data[idx:end].decode('utf-8', errors='replace')))
    idx = end

print(f"Found {len(found)} subresources in cache:")
for off, s in found:
    print(f"  Offset {hex(off)}: {s}")
