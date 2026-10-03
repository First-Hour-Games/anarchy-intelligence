import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        if 1860 <= idx <= 2000:
            src = data.get('source')
            typ = data.get('type')
            content = data.get('content', '')
            tcalls = data.get('tool_calls', [])
            print(f"Step {idx} [{src} / {typ}]: {content[:200]}")
            if tcalls:
                for tc in tcalls:
                    print(f"   Tool: {tc.get('name')}({str(tc.get('parameters'))[:150]})")
