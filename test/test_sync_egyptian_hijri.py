import calendar
import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parents[1]))
from tools import sync_egyptian_hijri as sync
from tools.sync_egyptian_hijri import merge_write, parse_month_html

def fixture(month=1, year=2026, days=None):
    days = days or calendar.monthrange(year, month)[1]
    rows = "".join(
        f'<tr><td>القاهرة</td><td>{year:04d}-{month:02d}-{day:02d}</td>'
        f'<td>{((day - 1) % 30) + 1} جماد الثاني 1447</td></tr>' for day in range(1, days + 1)
    )
    return '<table id="placeholder1_GridView1"><tr><th>المدينة</th><th>التاريخ الميلادي</th><th>التاريخ الهجري</th></tr>' + rows + '</table>'

FIXTURE = fixture()

class ParserTests(unittest.TestCase):
    def test_cairo_row_and_hijri_month(self):
        result = parse_month_html(FIXTURE, expected_month=1)
        self.assertEqual(len(result), 31)
        self.assertEqual(result["2026-01-01"], {"day": 1, "month": 6, "year": 1447})

    def test_year_is_not_inferred(self):
        with self.assertRaises(ValueError): parse_month_html(FIXTURE, expected_month=1, expected_year=2025)

    def test_missing_grid_rejected(self):
        with self.assertRaises(ValueError): parse_month_html("<html></html>")

    def test_missing_day_rejected(self):
        with self.assertRaisesRegex(ValueError, "incomplete"):
            parse_month_html(fixture(days=30), expected_month=1)

    def test_impossible_gregorian_day_rejected(self):
        html = fixture(month=2, days=28).replace("2026-02-28", "2026-02-30")
        with self.assertRaises(ValueError): parse_month_html(html, expected_month=2)

    def test_identical_duplicate_rejected(self):
        duplicate = FIXTURE.replace('</table>', '<tr><td>القاهرة</td><td>2026-01-01</td><td>1 جماد الثاني 1447</td></tr></table>')
        with self.assertRaisesRegex(ValueError, "duplicate"):
            parse_month_html(duplicate, expected_month=1)

    def test_invalid_hijri_year_rejected(self):
        with self.assertRaises(ValueError):
            parse_month_html(FIXTURE.replace("1447</td>", "0</td>"), expected_month=1)

    def test_mixed_gregorian_year_rejected(self):
        html = FIXTURE.replace("2026-01-31", "2025-01-31")
        with self.assertRaisesRegex(ValueError, "more than one"):
            parse_month_html(html, expected_month=1)


class MergeTests(unittest.TestCase):
    def test_partial_update_preserves_previous_year_and_replaces_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "calendar.json"
            old = {"2025-01-01": {"day": 1, "month": 7, "year": 1446}}
            output.write_text(json.dumps({"dates": old}), encoding="utf-8")
            records = {"2026-01-01": {"day": 12, "month": 6, "year": 1447}}
            with patch.object(sync, "OUT", output), patch.object(sync.os, "replace", wraps=sync.os.replace) as atomic_replace:
                payload = merge_write(records, "2026-01-01T00:00:00Z", [1])
            atomic_replace.assert_called_once()
            self.assertEqual(payload["dates"], {**old, **records})
            self.assertEqual(json.loads(output.read_text(encoding="utf-8"))["dates"], {**old, **records})
            self.assertFalse(list(Path(directory).glob("*.tmp")))

if __name__ == "__main__": unittest.main()
