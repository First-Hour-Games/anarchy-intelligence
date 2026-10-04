import ctypes
from ctypes import wintypes
import sys

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010

kernel32 = ctypes.windll.kernel32

kernel32.ReadProcessMemory.argtypes = [
    wintypes.HANDLE,
    ctypes.c_void_p,
    ctypes.c_void_p,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t)
]
kernel32.ReadProcessMemory.restype = wintypes.BOOL

kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

pid = 14708
handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
if not handle:
    print("Failed to open process")
    sys.exit(1)

# Center address
center_addr = 0xe5557f937c
start_addr = center_addr - 1000000
read_size = 2000000

buf = ctypes.create_string_buffer(read_size)
read_bytes = ctypes.c_size_t(0)

# Try reading from start_addr
if not kernel32.ReadProcessMemory(handle, ctypes.c_void_p(start_addr), buf, read_size, ctypes.byref(read_bytes)):
    print("Failed read from start_addr, trying smaller chunks around center...")
    # Read chunk around center
    start_addr = center_addr - 200000
    read_size = 400000
    buf = ctypes.create_string_buffer(read_size)
    kernel32.ReadProcessMemory(handle, ctypes.c_void_p(start_addr), buf, read_size, ctypes.byref(read_bytes))

print(f"Read {read_bytes.value} bytes around {hex(start_addr)}")
data = buf.raw[:read_bytes.value]
kernel32.CloseHandle(handle)

with open("scratch/godot_tscn_memory_dump.txt", "wb") as f:
    f.write(data)

print("Saved scratch/godot_tscn_memory_dump.txt")
