import os

log_dir = "/Users/duvanconde/.gemini/antigravity/brain/"
conversations = [
    "5836dc62-8679-45cd-a62a-7bfe0722ba5d",
    "526bf006-fa97-4ccb-9d64-59ca545d811d",
    "be073c2a-fb8b-4194-9587-bfaa9c3f06dd"
]

files_to_restore = [
    "product_detail_screen.dart",
    "rental_detail_screen.dart",
    "job_detail_screen.dart"
]

for conv in conversations:
    log_path = os.path.join(log_dir, conv, ".system_generated/logs/overview.txt")
    if not os.path.exists(log_path):
        continue
    
    with open(log_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    for fname in files_to_restore:
        idx = content.find(fname)
        if idx != -1:
            print(f"Found {fname} in {conv}. Context:")
            print(content[max(0, idx-100):idx+500])
            print("-" * 50)

