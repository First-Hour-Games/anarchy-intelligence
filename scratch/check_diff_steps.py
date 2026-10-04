import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        if data.get('step_index') in [1876, 1877, 1986, 1987]:
            print(f"=== Step {data.get('step_index')} ===")
            print(data.get('content') or data.get('tool_calls'))
