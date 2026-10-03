import ctypes
from ctypes import wintypes
import sys

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010

kernel32 = ctypes.windll.kernel32

pid = 14708
handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
if not handle:
    print(f"Failed to open process {pid}, error: {kernel32.GetLastError()}")
else:
    print(f"Successfully opened process {pid}! Handle: {handle}")
    kernel32.CloseHandle(handle)
