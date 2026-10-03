import ctypes
from ctypes import wintypes
import sys

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010

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

kernel32.VirtualQueryEx.argtypes = [
    wintypes.HANDLE,
    ctypes.c_void_p,
    ctypes.POINTER(MEMORY_BASIC_INFORMATION),
    ctypes.c_size_t
]
kernel32.VirtualQueryEx.restype = ctypes.c_size_t

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

target_addr = 0xe5557f937c
mbi = MEMORY_BASIC_INFORMATION()
res = kernel32.VirtualQueryEx(handle, ctypes.c_void_p(target_addr), ctypes.byref(mbi), ctypes.sizeof(mbi))
if not res:
    print("VirtualQueryEx failed")
    sys.exit(1)

print(f"BaseAddress: {hex(mbi.BaseAddress or 0)}, RegionSize: {mbi.RegionSize}, State: {mbi.State}, Protect: {mbi.Protect}")

buf = ctypes.create_string_buffer(mbi.RegionSize)
read_bytes = ctypes.c_size_t(0)
if kernel32.ReadProcessMemory(handle, ctypes.c_void_p(mbi.BaseAddress), buf, mbi.RegionSize, ctypes.byref(read_bytes)):
    print(f"Successfully read {read_bytes.value} bytes from base {hex(mbi.BaseAddress)}")
    with open("scratch/full_page_dump.bin", "wb") as f:
        f.write(buf.raw[:read_bytes.value])
    print("Saved to scratch/full_page_dump.bin")
else:
    print(f"Read failed, error: {kernel32.GetLastError()}")

kernel32.CloseHandle(handle)
