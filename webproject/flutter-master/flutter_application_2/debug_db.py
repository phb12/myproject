import sqlite3

conn = sqlite3.connect('db.sqlite3')
c = conn.cursor()
c.execute("SELECT id, username, date, caption, image_url, created_at FROM posts ORDER BY created_at DESC LIMIT 5")
rows = c.fetchall()

print("Recent posts:")
for row in rows:
    print(row)

conn.close()
