import json

transcript_path = r'C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index')
        if idx in [2026, 2027, 2057, 2058]:
            print(f"=== STEP {idx} ===")
            if data.get('tool_calls'):
                print("tool_calls:", data['tool_calls'])
            if data.get('content'):
                print("content length:", len(data['content']))
                print("content preview:", data['content'][:500])
