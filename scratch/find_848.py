import json

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        content = data.get('content', '')
        if 1860 <= idx <= 2100:
            if 'starting_forest.tscn' in content and 'Total Lines: 848' in content:
                print(f"Match at step {idx}!")
                print(content[:500])
