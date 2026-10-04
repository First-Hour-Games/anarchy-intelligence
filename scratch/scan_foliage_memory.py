import ctypes
from ctypes import wintypes
import sys
import os

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
MEM_COMMIT = 0x1000
PAGE_READWRITE = 0x04
PAGE_READONLY = 0x02
PAGE_EXECUTE_READWRITE = 0x40

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
kernel32.CloseHandle.restype = wintypes.BOOL

pid = 14708
handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
if not handle:
    print(f"Failed to open process {pid}")
    sys.exit(1)

mbi = MEMORY_BASIC_INFORMATION()
address = 0
max_address = 0x7FFFFFFF0000

targets = [
    b'MultiMesh_y0hyv',
    b'MultiMesh_s25nh',
    b'MultiMesh_4x0ik',
    b'MultiMesh_2mla1',
    b'TreePlacement5',
    b'ArrayMesh_2mla1',
]

results = {t: [] for t in targets}
read_bytes = ctypes.c_size_t(0)

print(f"Scanning PID {pid} memory for targets: {[t.decode() for t in targets]}...")

scanned_regions = 0
found_total = 0

while address < max_address:
    res = kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(mbi), ctypes.sizeof(mbi))
    if not res:
        break
    
    base_addr = mbi.BaseAddress or address
    size = mbi.RegionSize
    
    if mbi.State == MEM_COMMIT and (mbi.Protect & 0xFF) in (PAGE_READWRITE, PAGE_READONLY, PAGE_EXECUTE_READWRITE):
        if size <= 64 * 1024 * 1024:
            scanned_regions += 1
            buf = ctypes.create_string_buffer(size)
            if kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base_addr), buf, size, ctypes.byref(read_bytes)):
                data = buf.raw[:read_bytes.value]
                for target in targets:
                    idx = 0
                    while True:
                        idx = data.find(target, idx)
                        if idx == -1:
                            break
                        found_total += 1
                        print(f"Match for {target.decode()} at region {hex(base_addr)} offset {hex(idx)}")
                        # Check surrounding context
                        start = max(0, idx - 500)
                        end = min(len(data), idx + 2000)
                        chunk = data[start:end]
                        results[target].append((base_addr + idx, chunk))
                        idx += len(target)
                        if len(results[target]) >= 10:
                            break

    address = base_addr + size

kernel32.CloseHandle(handle)
print(f"Done scanning {scanned_regions} regions. Found {found_total} matches.")

os.makedirs('scratch/matches', exist_ok=True)
for target, matches in results.items():
    t_name = target.decode()
    for i, (addr, chunk) in enumerate(matches):
        filename = f"scratch/matches/{t_name}_{i}_{hex(addr)}.bin"
        with open(filename, "wb") as f:
            f.write(chunk)
        # Also print preview if text-like
        print(f"\n--- {t_name} #{i} (addr: {hex(addr)}) ---")
        try:
            print(chunk.decode('utf-8', errors='replace')[:400])
        except Exception as e:
            print(e)
