import json
import os

with open('.dart_tool/package_config.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for pkg in data.get('packages', []):
    uri = pkg.get('rootUri', '')
    if uri.startswith('file:///'):
        path = uri[8:]
    elif uri.startswith('../'):
        path = os.path.abspath(uri)
    else:
        path = uri
    hook_path = os.path.join(path, 'hook')
    if os.path.exists(hook_path):
        print(f"Package with hook: {pkg.get('name')} at {hook_path}")
