import urllib.request
import traceback
try:
    with urllib.request.urlopen("https://di107.dar-alifta.org/api/HijriDate?langID=2", timeout=5) as r:
        print("HTTPS SUCCESS:", r.read().decode())
except Exception as e:
    print("HTTPS FAILED:", e)

try:
    with urllib.request.urlopen("http://di107.dar-alifta.org/api/HijriDate?langID=2", timeout=5) as r:
        print("HTTP SUCCESS:", r.read().decode())
except Exception as e:
    print("HTTP FAILED:", e)
