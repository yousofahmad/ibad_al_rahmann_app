import sqlite3
import traceback

try:
    conn = sqlite3.connect('assets/databases/qpc-v1-glyph-codes-wbw.db')
    c = conn.cursor()
    c.execute("ATTACH DATABASE 'assets/databases/qpc-v1-15-lines.db' AS map_db")

    def get_page_lines(p):
        try:
            c.execute(f"SELECT line_number, is_centered, surah_number FROM map_db.pages m WHERE m.page_number = {p} ORDER BY m.line_number")
            return c.fetchall()
        except Exception as e:
            return str(e)

    print('449:', get_page_lines(449))
    print('546:', get_page_lines(546))
    print('476:', get_page_lines(476))
    print('534:', get_page_lines(534))
except Exception as e:
    traceback.print_exc()
