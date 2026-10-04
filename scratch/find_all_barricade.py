import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        content = data.get('content', '')
        # Check tool calls
        tcalls = str(data.get('tool_calls', ''))
        # Check thinking
        thinking = str(data.get('thinking', ''))
        
        full_text = content + " " + tcalls + " " + thinking
        if 'barricade' in full_text.lower():
            print(f"Step {idx}: contains 'barricade'")
            # print where it appears
            for field, text in [('content', content), ('tool_calls', tcalls), ('thinking', thinking)]:
                if 'barricade' in text.lower():
                    print(f"  In {field}:")
                    # print lines with barricade
                    for l in text.splitlines():
                        if 'barricade' in l.lower() or 'transform' in l.lower():
                            print("   ", l[:120])
