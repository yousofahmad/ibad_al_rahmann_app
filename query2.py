import sqlite3

conn = sqlite3.connect('assets/databases/qpc-v1-glyph-codes-wbw.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = c.fetchall()
print('Tables:', tables)

for table in tables:
    c.execute(f"PRAGMA table_info({table[0]});")
    print(f'Columns for {table[0]}:', c.fetchall())

