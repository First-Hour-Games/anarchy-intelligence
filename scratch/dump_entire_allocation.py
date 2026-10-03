import ctypes
from ctypes import wintypes
import sys

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
MEM_COMMIT = 0x1000

kernel32 = ctypes.windll.kernel32

class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", ctypes.c_void_p),
        ("AllocationBase", ctypes.c_void_p),
        ("AllocationProtect", wintypes.DWORD),
        ("PartitionId", wintypes.WORD),
        ("RegionSize", ctypes.c_size_t),
        ("State", wintypes.DWORD),
        ("Protect", wintypes.DWORD),
        ("Type", wintypes.DWORD),
    ]

kernel32.VirtualQueryEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.POINTER(MEMORY_BASIC_INFORMATION), ctypes.c_size_t]
kernel32.VirtualQueryEx.restype = ctypes.c_size_t
kernel32.ReadProcessMemory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
kernel32.ReadProcessMemory.restype = wintypes.BOOL
kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, 14708)
if not handle:
    print("Failed to open process")
    sys.exit(1)

alloc_base = 0xe555000000
current = alloc_base
end_alloc = 0xe560000000

mbi = MEMORY_BASIC_INFORMATION()
all_data = bytearray()
read_bytes = ctypes.c_size_t(0)

while current < end_alloc:
    res = kernel32.VirtualQueryEx(handle, ctypes.c_void_p(current), ctypes.byref(mbi), ctypes.sizeof(mbi))
    if not res:
        break
    base = mbi.BaseAddress or current
    size = mbi.RegionSize
    if mbi.State == MEM_COMMIT:
        buf = ctypes.create_string_buffer(size)
        if kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base), buf, size, ctypes.byref(read_bytes)):
            all_data.extend(buf.raw[:read_bytes.value])
    current = base + size

kernel32.CloseHandle(handle)
print(f"Total committed bytes read: {len(all_data)}")

with open("scratch/allocation_dump.bin", "wb") as f:
    f.write(all_data)

print("Saved to scratch/allocation_dump.bin")
