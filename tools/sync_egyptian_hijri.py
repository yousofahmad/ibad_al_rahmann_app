#!/usr/bin/env python3
"""Fetch the official ESA monthly table for Cairo and merge Gregorian/Hijri dates.

No calendar arithmetic is performed: every date written here must be present in
an ESA response.  The endpoint is ASP.NET and therefore each month is a fresh
GET + form POST carrying the current hidden state.
"""
from __future__ import annotations
import argparse, calendar, datetime as dt, json, os, re, sys, tempfile
from pathlib import Path
from typing import Any
import requests
from bs4 import BeautifulSoup

SOURCE_URL = "https://www.esa.gov.eg/monthlymwaket.aspx"
CITY_VALUE = "القـاهـرة"  # exact option value (contains tatweel); display is القاهرة
OUT = Path(__file__).resolve().parents[1] / "assets/data/egyptian_hijri_calendar.json"
AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
MONTHS = range(1, 13)


def _plain(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\u200f", "").replace("\u200e", "").replace("ـ", "").translate(AR_DIGITS)).strip()


def parse_month_html(html: str, *, expected_month: int | None = None, expected_year: int | None = None) -> dict[str, dict[str, int]]:
    """Parse the Cairo rows from an ESA monthly response.

    The year is read from each returned Gregorian date; it is never inferred
    from a requested year.  Raises ValueError on missing/duplicate/inconsistent
    rows so a broken postback cannot overwrite good data.
    """
    soup = BeautifulSoup(html, "html.parser")
    table = soup.select_one("table#placeholder1_GridView1")
    if table is None:
        raise ValueError("ESA response has no monthly GridView")
    rows = table.find_all("tr")
    result: dict[str, dict[str, int]] = {}
    table_year: int | None = None
    table_month: int | None = None
    for tr in rows[1:]:
        cells = [_plain(c.get_text(" ", strip=True)) for c in tr.find_all(["td", "th"])]
        if len(cells) < 3 or cells[0] not in ("القاهرة", "القـاهـرة"):
            continue
        m = re.fullmatch(r"(\d{4})-(\d{1,2})-(\d{1,2})", cells[1])
        hm = re.search(r"(\d{1,2})\s+(.+?)\s+(\d{3,4})$", cells[2])
        if not m or not hm:
            raise ValueError(f"unrecognised date row: {cells[:3]!r}")
        year, month, day = map(int, m.groups())
        hday, hname, hyear = int(hm.group(1)), hm.group(2).strip(), int(hm.group(3))
        try:
            gregorian = dt.date(year, month, day)
        except ValueError as exc:
            raise ValueError(f"invalid Gregorian date: {cells[:3]!r}") from exc
        if not 1 <= hday <= 30 or not 1 <= hyear <= 9999:
            raise ValueError(f"invalid date values: {cells[:3]!r}")
        if table_year is None:
            table_year, table_month = gregorian.year, gregorian.month
        if (gregorian.year, gregorian.month) != (table_year, table_month):
            raise ValueError("Cairo table contains more than one Gregorian year/month")
        if expected_month is not None and month != expected_month:
            raise ValueError(f"returned year/month {year}-{month:02d}, expected month {expected_month}")
        if expected_year is not None and year != expected_year:
            raise ValueError(f"returned year {year}, expected {expected_year}")
        key = f"{year:04d}-{month:02d}-{day:02d}"
        value = {"day": hday, "month": _hijri_month_number(hname), "year": hyear}
        if key in result:
            raise ValueError(f"duplicate date {key}")
        result[key] = value
    if not result:
        raise ValueError("ESA response contains no Cairo rows")
    assert table_year is not None and table_month is not None
    expected_days = {f"{table_year:04d}-{table_month:02d}-{day:02d}"
                     for day in range(1, calendar.monthrange(table_year, table_month)[1] + 1)}
    missing = expected_days - result.keys()
    if missing:
        raise ValueError(f"incomplete Cairo month; missing {sorted(missing)[:3]}")
    return result


def _hijri_month_number(name: str) -> int:
    names = ["محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جماد الأول", "جماد الثاني", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]
    normalized = name.replace("ـ", "").replace(" ", "").replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي").replace("ثاني", "ثانى")
    if normalized.startswith("ال"):
        normalized = normalized[2:]
    normalized = normalized.replace("الاخر", "الثانى")
    for i, n in enumerate(names, 1):
        candidate = n.replace("أ", "ا").replace(" ", "").replace("ى", "ي")
        candidate = candidate.replace("ثاني", "ثانى")
        if normalized == candidate or normalized.startswith(candidate):
            return i
    raise ValueError(f"unknown ESA Hijri month: {name!r}")


def _form_state(soup: BeautifulSoup) -> dict[str, str]:
    return {x["name"]: x.get("value", "") for x in soup.select("form#ctl00 input[type=hidden][name]")}


def fetch_month(session: requests.Session, month: int, timeout: int = 45) -> dict[str, dict[str, int]]:
    r = session.get(SOURCE_URL, timeout=timeout)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    city = next((o.get("value") for o in soup.select("#placeholder1_DropDownList1 option")
                 if _plain(o.get_text()) == "القاهرة"), CITY_VALUE)
    data = _form_state(soup)
    data.update({"ctl00$placeholder1$DropDownList1": city, "ctl00$placeholder1$DropDownList2": str(month)})
    r = session.post(SOURCE_URL, data=data, headers={"Referer": SOURCE_URL}, timeout=timeout)
    r.raise_for_status()
    return parse_month_html(r.text, expected_month=month)


def merge_write(records: dict[str, dict[str, int]], fetched_at: str, months: list[int]) -> dict[str, Any]:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    existing: dict[str, Any] = {}
    if OUT.exists():
        try: existing = json.loads(OUT.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError): existing = {}
    dates = dict(existing.get("dates", {}))
    dates.update(records)
    years = sorted({int(k[:4]) for k in dates})
    payload = {
        "schemaVersion": 1,
        "source": {"name": "الهيئة المصرية العامة للمساحة", "url": SOURCE_URL, "city": "القاهرة"},
        "fetchedAt": fetched_at,
        "dates": dict(sorted(dates.items())),
        "coverage": {"recordCount": len(dates), "fetchedMonths": months, "gregorianYears": years, "officialOnly": True, "calculatedDates": False},
    }
    fd, tmp_name = tempfile.mkstemp(prefix=f".{OUT.name}.", suffix=".tmp", dir=OUT.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, OUT)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise
    return payload


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--months", default="1-12", help="month numbers/ranges, default all 12")
    args = ap.parse_args()
    months: list[int] = []
    for part in args.months.split(","):
        if "-" in part:
            a, b = map(int, part.split("-", 1)); months.extend(range(a, b + 1))
        else: months.append(int(part))
    months = sorted(set(months))
    if any(m not in MONTHS for m in months): raise SystemExit("months must be 1..12")
    session = requests.Session(); session.headers.update({"User-Agent": "ibad-al-rahmann-ESA-sync/1.0"})
    all_records: dict[str, dict[str, int]] = {}; completed = []
    for month in months:
        records = fetch_month(session, month)
        overlap = set(all_records) & set(records)
        if overlap: raise RuntimeError(f"duplicate dates across monthly tables: {sorted(overlap)[:3]}")
        all_records.update(records); completed.append(month)
        print(f"month {month:02d}: {len(records)} Cairo records", file=sys.stderr)
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    payload = merge_write(all_records, now, completed)
    print(f"wrote {OUT} ({payload['coverage']['recordCount']} total records)")
    return 0

if __name__ == "__main__": raise SystemExit(main())
