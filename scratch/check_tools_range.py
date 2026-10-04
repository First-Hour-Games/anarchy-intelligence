import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        if 1990 <= idx <= 2075:
            tcalls = data.get('tool_calls', [])
            for tc in tcalls:
                name = tc.get('name')
                args = tc.get('args', {})
                print(f"Step {idx}: {name}({str(args)[:150]})")
