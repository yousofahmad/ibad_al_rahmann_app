import sqlite3
import traceback

try:
    conn = sqlite3.connect('assets/databases/qpc-v1-glyph-codes-wbw.db')
    c = conn.cursor()

    def get_page(p):
        try:
            # Let's check schema first to see table names
            c.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = c.fetchall()
            # print('Tables:', tables)
            
            c.execute(f"SELECT text FROM words WHERE page_number = {p} LIMIT 10")
            return ' '.join([x[0] for x in c.fetchall()])
        except Exception as e:
            return str(e)

    print('449:', get_page(449))
    print('546:', get_page(546))
except Exception as e:
    traceback.print_exc()
