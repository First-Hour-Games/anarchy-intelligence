import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        if 1997 <= idx <= 2025 and data.get('tool_calls'):
            for tc in data.get('tool_calls'):
                if tc.get('name') == 'write_to_file':
                    print(f"=== Step {idx} ===")
                    print(tc.get('args', {}).get('TargetFile'))
                    print(tc.get('args', {}).get('CodeContent'))
