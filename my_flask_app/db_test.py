import mysql.connector

db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="12345678",
    database="hotel_db"
)

cursor = db.cursor()
cursor.execute("SELECT * FROM rooms;")
print(cursor.fetchall())