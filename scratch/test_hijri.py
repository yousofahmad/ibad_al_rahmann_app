import math

def get_arabic_date(y, m, day):
    if m < 3:
        y -= 1
        m += 12
    a = int(y / 100)
    b = 2 - a + int(a / 4)
    jd = math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + day + b - 1524.5
    z = jd + 0.5
    cyc = int((z - 1948439.5) / 10631.0)
    rem = z - 1948439.5 - cyc * 10631.0
    j = int((rem - 0.12) / 354.3666)
    res = rem - math.floor(j * 354.3666 + 0.5)
    hYear = cyc * 30 + j + 1
    hMonth = int((res + 28.5001) / 29.5)
    if hMonth == 13:
        hMonth = 12
    hDay = int(res - math.floor(hMonth * 29.5 - 28.999))
    if hDay == 0:
        hDay = 1
    return hDay, hMonth, hYear

print("15:", get_arabic_date(2026, 6, 15))
print("16:", get_arabic_date(2026, 6, 16))
print("17:", get_arabic_date(2026, 6, 17))
print("18:", get_arabic_date(2026, 6, 18))
print("19:", get_arabic_date(2026, 6, 19))
