import urllib.request
import traceback

req = urllib.request.Request("http://di107.dar-alifta.org/api/HijriDate?langID=2", headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        print("HTTP SUCCESS:", r.read().decode('utf-16' if r.headers.get_content_charset() == 'utf-16' else 'utf-8', errors='ignore'))
except Exception as e:
    print("HTTP FAILED:", e)

req2 = urllib.request.Request("https://di107.dar-alifta.org/api/HijriDate?langID=2", headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req2, timeout=10) as r:
        print("HTTPS SUCCESS:", r.read().decode('utf-16' if r.headers.get_content_charset() == 'utf-16' else 'utf-8', errors='ignore'))
except Exception as e:
    print("HTTPS FAILED:", e)
