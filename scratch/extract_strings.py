import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('scratch/full_page_dump.bin', 'rb') as f:
    data = f.read()

# Let's find all text strings in full_page_dump.bin
# by finding printable ASCII/UTF-8 sequences of length >= 10
import re
strings = re.findall(b'[\x20-\x7E\r\n]{10,}', data)
for s in strings:
    text = s.decode('ascii', errors='ignore').strip()
    if len(text) > 20:
        print("=== STRING ===")
        print(text[:300])
        print("...")
