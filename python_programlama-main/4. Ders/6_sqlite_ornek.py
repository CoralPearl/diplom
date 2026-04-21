"""
b.vt veri tabanını oluşturunuz

iris isminde bir tablo oluşturunuz

bu tabloyu iris.data dosyasındaki verilere uygun şekilde alanlar
oluşturunuz

iris.data dosyasındaki verileri iris tablosuna ekleyiniz
"""

# import csv
# import sqlite3
#
# bag = sqlite3.connect("b.vt")
# cursor = bag.cursor()
#
# cursor.execute("CREATE TABLE IF NOT EXISTS iris "
#                "(id INTEGER NOT NULL PRIMARY KEY,"
#                "species TEXT, sepal_length FLOAT, "
#                "sepal_width FLOAT, "
#                "petal_length FLOAT, "
#                "petal_width FLOAT)")
#
#
# with open('iris.data', newline='') as csvfile:
#     reader = csv.DictReader(csvfile)
#     for row in reader:
#         cursor.execute("INSERT INTO iris (species, sepal_length, sepal_width, petal_length, petal_width) "
#                        "VALUES(?, ?, ?, ?, ?)", (row["species"], row["sepal_length"], row["sepal_width"], row["petal_length"], row["petal_width"]))
# bag.commit()
# bag.close()
import csv
import sqlite3

# 1. Создаём (или открываем) базу данных
bag = sqlite3.connect("b.vt")  # создаётся файл b.vt в текущей папке
cursor = bag.cursor()  # создаём объект курсора для выполнения SQL-команд

# 2. Создаём таблицу iris, если её нет
cursor.execute("""
CREATE TABLE IF NOT EXISTS iris (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    sepal_length FLOAT,
    sepal_width FLOAT,
    petal_length FLOAT,
    petal_width FLOAT,
    species TEXT
)
""")

# 3. Открываем CSV-файл и читаем построчно
with open('iris.data', newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        # 4. Добавляем каждую строку в таблицу
        cursor.execute("""
        INSERT INTO iris (sepal_length, sepal_width, petal_length, petal_width, species)
        VALUES (?, ?, ?, ?, ?)
        """, (
            float(row["sepal_length"]),
            float(row["sepal_width"]),
            float(row["petal_length"]),
            float(row["petal_width"]),
            row["species"]
        ))

# 5. Сохраняем изменения
bag.commit()

# 6. Закрываем соединение
bag.close()

print("✅ Данные успешно добавлены в базу 'b.vt'")