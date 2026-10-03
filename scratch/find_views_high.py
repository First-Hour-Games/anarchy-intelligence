import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        tcalls = data.get('tool_calls', [])
        for tc in tcalls:
            if tc.get('name') == 'view_file':
                args = tc.get('args', {})
                if 'starting_forest.tscn' in args.get('AbsolutePath', ''):
                    sl = args.get('StartLine', 0)
                    el = args.get('EndLine', 0)
                    if sl > 450 or el > 450:
                        print(f"Step {idx}: view_file {sl} to {el}")
