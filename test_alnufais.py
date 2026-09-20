import urllib.request
url = "https://raw.githubusercontent.com/islamic-network/cdn/master/audio/reciters/surah-recitation-ahmad-alnufais/surah.json"
try:
    response = urllib.request.urlopen(url)
    print(response.read().decode('utf-8')[:100])
except Exception as e:
    print(f"Error: {e}")
