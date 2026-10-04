import json

transcript_path = r"C:\Users\ADMIN\.gemini\antigravity\brain\4728e06f-5445-4443-a9d6-83a485e0782c\.system_generated\logs\transcript_full.jsonl"
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get('step_index', 0)
        tcalls = data.get('tool_calls', [])
        for tc in tcalls:
            args = tc.get('args', {})
            fn = str(args.get('TargetFile') or args.get('AbsolutePath') or args.get('CommandLine'))
            if 'starting_forest.tscn' in fn:
                print(f"Step {idx}: {tc.get('name')}")
                if 'StartLine' in args:
                    print(f"   Lines: {args.get('StartLine')} to {args.get('EndLine')}")
                if 'Instruction' in args:
                    print(f"   Instruction: {args.get('Instruction')}")
                if 'CommandLine' in args:
                    print(f"   Cmd: {args.get('CommandLine')[:100]}")
