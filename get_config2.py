import json
import urllib.request

url = "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/app_config.json"
try:
    with urllib.request.urlopen(url) as response:
        text = response.read().decode('utf-8')
        if '546' in text or '449' in text:
            print("Found 546 or 449 in the JSON!")
        else:
            print("Not found.")
except Exception as e:
    print(e)
