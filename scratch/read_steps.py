import json

transcript_path = r'C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index')
        if idx and 1990 <= idx <= 2060:
            tc = data.get('tool_calls')
            if tc:
                name = tc[0].get('name')
                args = tc[0].get('args')
                if name == 'run_command':
                    print(f"Step {idx} run: {args.get('CommandLine', '')[:100]}")
                elif name == 'view_file':
                    print(f"Step {idx} view: {args.get('AbsolutePath')}")
                elif name == 'replace_file_content':
                    print(f"Step {idx} replace: {args.get('TargetFile')}")
                elif name == 'write_to_file':
                    print(f"Step {idx} write: {args.get('TargetFile')}")
                else:
                    print(f"Step {idx} {name}")
