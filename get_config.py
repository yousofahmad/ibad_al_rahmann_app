import json
import urllib.request

url = "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/app_config.json"
try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read().decode())
        if 'audio_reciters' in data:
            for r in data['audio_reciters']:
                print(r.get('id'), r.get('name'))
except Exception as e:
    print(e)
