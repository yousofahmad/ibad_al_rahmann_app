import sqlite3

conn = sqlite3.connect('assets/databases/qpc-v1-15-lines.db')
c = conn.cursor()

def get_page_info(p):
    c.execute(f"SELECT * FROM pages WHERE page_number = {p} LIMIT 1")
    return c.fetchone()

print('449:', get_page_info(449))
print('546:', get_page_info(546))
print('476:', get_page_info(476))
print('534:', get_page_info(534))
