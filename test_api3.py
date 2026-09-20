import urllib.request
try:
    req = urllib.request.Request("https://dar-alifta.org/api/HijriDate?langID=2", headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=5) as r:
        print(" dar-alifta.org HTTPS SUCCESS:", r.read().decode('utf-8'))
except Exception as e:
    print(" dar-alifta.org HTTPS FAILED:", e)
