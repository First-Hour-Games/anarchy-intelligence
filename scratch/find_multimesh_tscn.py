import ctypes
from ctypes import wintypes

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010

kernel32 = ctypes.windll.kernel32
pid = 14708
handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)

# Let's inspect memory around 0x2e3dd85bb41
# In Godot, a Resource object in memory is a C++ Object.
# But was the .tscn text itself loaded or saved?
# Let's search memory for text: '[sub_resource type="MultiMesh" id="MultiMesh_y0hyv"]'
target = b'id="MultiMesh_y0hyv"'
# Or target = b'MultiMesh_y0hyv'

# Let's search memory for any chunk containing '[sub_resource type="MultiMesh"' AND 'MultiMesh_y0hyv'
print("Searching for MultiMesh_y0hyv text definition...")

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

mbi = MEMORY_BASIC_INFORMATION()
address = 0
max_address = 0x7FFFFFFF0000
read_bytes = ctypes.c_size_t(0)

found_texts = []
while address < max_address:
    res = kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(mbi), ctypes.sizeof(mbi))
    if not res:
        break
    base_addr = mbi.BaseAddress or address
    size = mbi.RegionSize
    if mbi.State == 0x1000 and (mbi.Protect & 0xFF) in (0x04, 0x02, 0x40):
        if size <= 64 * 1024 * 1024:
            buf = ctypes.create_string_buffer(size)
            if kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base_addr), buf, size, ctypes.byref(read_bytes)):
                data = buf.raw[:read_bytes.value]
                if b'MultiMesh_y0hyv' in data:
                    idx = data.find(b'MultiMesh_y0hyv')
                    s = max(0, idx - 200)
                    e = min(len(data), idx + 1000)
                    chunk = data[s:e]
                    if b'[sub_resource' in chunk or b'instance_count' in chunk:
                        print(f"Found tscn-like chunk at {hex(base_addr + idx)}:")
                        print(chunk.decode('utf-8', errors='replace'))
                        found_texts.append(chunk)
    address = base_addr + size

kernel32.CloseHandle(handle)
print(f"Total tscn chunks found: {len(found_texts)}")
