import ctypes
from ctypes import wintypes
import sys

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
    b'[node name="barricade"',
    b'treeMulti8',
    b'MultiMesh_y0hyv',
    b'MultiMesh_s25nh',
    b'MultiMesh_4x0ik',
    b'MultiMesh_2mla1',
    b'TreePlacement4',
    b'TreePlacement5',
    b'res://models/barricade/barricade.glb',
]

found_chunks = []
read_bytes = ctypes.c_size_t(0)

print("Scanning memory...")
matches = 0
while address < max_address:
    res = kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(mbi), ctypes.sizeof(mbi))
    if not res:
        break
    
    base_addr = mbi.BaseAddress or address
    size = mbi.RegionSize
    
    if mbi.State == MEM_COMMIT and (mbi.Protect & 0xFF) in (PAGE_READWRITE, PAGE_READONLY, PAGE_EXECUTE_READWRITE):
        if size <= 32 * 1024 * 1024:
            buf = ctypes.create_string_buffer(size)
            if kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base_addr), buf, size, ctypes.byref(read_bytes)):
                data = buf.raw[:read_bytes.value]
                for target in targets:
                    idx = 0
                    while True:
                        idx = data.find(target, idx)
                        if idx == -1:
                            break
                        matches += 1
                        start = max(0, idx - 1000)
                        end = min(len(data), idx + 3000)
                        chunk = data[start:end]
                        found_chunks.append((target.decode('utf-8', errors='ignore'), chunk))
                        print(f"Found match #{matches} for {target.decode('utf-8', errors='ignore')} at {hex(address + idx)}!")
                        try:
                            text = chunk.decode('utf-8', errors='ignore')
                            print("--- PREVIEW ---")
                            print(text[:300].strip())
                            print("---------------")
                        except Exception as e:
                            pass
                        idx += len(target)
                        if matches >= 50:
                            break
                    if matches >= 50:
                        break
    if matches >= 50:
        break
    address = base_addr + size

kernel32.CloseHandle(handle)
print(f"Done scanning. Total matches: {matches}")

with open("scratch/memory_dump_chunks.txt", "wb") as f:
    for target, chunk in found_chunks:
        f.write(f"\n\n================ TARGET: {target} ================\n".encode('utf-8'))
        f.write(chunk)
print("Saved to scratch/memory_dump_chunks.txt")
