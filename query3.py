import sqlite3
import traceback

try:
    conn = sqlite3.connect('assets/databases/qpc-v1-glyph-codes-wbw.db')
    c = conn.cursor()
    c.execute("ATTACH DATABASE 'assets/databases/qpc-v1-15-lines.db' AS map_db")

    def get_page(p):
        try:
            c.execute(f"SELECT text FROM map_db.pages m LEFT JOIN words w ON w.id BETWEEN m.first_word_id AND m.last_word_id WHERE m.page_number = {p} ORDER BY m.line_number, w.id LIMIT 10")
            return ' '.join([str(x[0]) for x in c.fetchall()])
        except Exception as e:
            return str(e)

    print('449:', get_page(449))
    print('546:', get_page(546))
    print('476:', get_page(476))
    print('534:', get_page(534))
except Exception as e:
    traceback.print_exc()
