import urllib.request
try:
    req = urllib.request.Request("https://dar-alifta.org/api/HijriDate?langID=2", headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=5) as r:
        with open("dar-alifta.txt", "wb") as f:
            f.write(r.read())
        print("Success, written to dar-alifta.txt")
except Exception as e:
    print("FAILED:", e)
