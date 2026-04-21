from flask import Flask, render_template, request, redirect, flash, url_for
import mysql.connector
import logging

logging.basicConfig(level=logging.INFO)

app = Flask(__name__)
app.secret_key = "any-secret-string"

# Настройка подключения к БД — проверь параметры
db = mysql.connector.connect(
    host="localhost",
    user="flaskuser",        # твой пользователь
    password="12345678",    # твой пароль
    database="hotel_db",
    autocommit=False
)

# --- Главная: список категорий ---
@app.route("/")
def home():
    cursor = db.cursor()
    cursor.execute("SELECT DISTINCT category FROM rooms WHERE category IS NOT NULL;")
    categories = [row[0] for row in cursor.fetchall()]
    cursor.close()
    return render_template("index.html", categories=categories)

# --- Страница категории: показать комнаты + обработать бронирование ---
@app.route("/category/<category>", methods=["GET", "POST"])
def show_category(category):
    cursor = db.cursor(dictionary=True)

    if request.method == "POST":
        # читаем данные формы
        client_name = request.form.get("client_name", "").strip()
        room_id = request.form.get("room_id")
        check_in = request.form.get("check_in")
        check_out = request.form.get("check_out")

        # базовая валидация
        if not client_name or not room_id or not check_in or not check_out:
            flash("Пожалуйста, заполните все поля.")
            return redirect(url_for("show_category", category=category))
        try:
            room_id = int(room_id)
        except ValueError:
            flash("Некорректный номер комнаты.")
            return redirect(url_for("show_category", category=category))

        if check_in >= check_out:
            flash("Дата выезда должна быть позже даты заезда.")
            return redirect(url_for("show_category", category=category))

        try:
            # Начинаем транзакцию и блокируем строку комнаты для избежания гонок
            # db.start_transaction()
            cursor.execute("SELECT id FROM rooms WHERE id = %s FOR UPDATE;", (room_id,))
            room_row = cursor.fetchone()
            if not room_row:
                db.rollback()
                flash("Комната не найдена.")
                return redirect(url_for("show_category", category=category))

            # Проверка пересечения: если существует бронь, которая НЕ полностью до new.check_in и НЕ полностью после new.check_out
            cursor.execute("""
                SELECT COUNT(*) AS cnt FROM bookings
                WHERE room_id = %s
                  AND NOT (check_out <= %s OR check_in >= %s)
            """, (room_id, check_in, check_out))
            cnt_row = cursor.fetchone()
            # cnt_row может быть dict или tuple в зависимости от cursor
            if isinstance(cnt_row, dict):
                cnt = cnt_row.get("cnt", 0)
            else:
                cnt = cnt_row[0] if cnt_row else 0

            if cnt > 0:
                db.rollback()
                flash("Комната уже занята в выбранный период.")
                return redirect(url_for("show_category", category=category))

            # вставляем бронь
            cursor.execute("""
                INSERT INTO bookings (room_id, client_name, check_in, check_out)
                VALUES (%s, %s, %s, %s)
            """, (room_id, client_name, check_in, check_out))
            db.commit()
            flash("Бронирование успешно создано!")
            return redirect(url_for("bookings"))
        except mysql.connector.Error as err:
            db.rollback()
            app.logger.exception("DB error during booking")
            flash(f"Ошибка базы данных: {err}")
            return redirect(url_for("show_category", category=category))
        except Exception as e:
            db.rollback()
            app.logger.exception("Unexpected error during booking")
            flash("Произошла ошибка при бронировании.")
            return redirect(url_for("show_category", category=category))

    # GET: показать комнаты данной категории
    cursor.execute("SELECT * FROM rooms WHERE category = %s ORDER BY room_number;", (category,))
    rooms = cursor.fetchall()
    cursor.close()
    return render_template("category.html", category=category, rooms=rooms)


# --- Мои брони ---
@app.route("/bookings")
def bookings():
    cursor = db.cursor(dictionary=True)
    cursor.execute("""
        SELECT b.id, b.client_name, b.check_in, b.check_out, r.room_number, r.category
        FROM bookings b
        LEFT JOIN rooms r ON b.room_id = r.id
        ORDER BY b.check_in DESC
    """)
    rows = cursor.fetchall()
    cursor.close()
    return render_template("bookings.html", bookings=rows)


# --- Удаление брони ---
@app.route("/delete/<int:booking_id>", methods=["GET"])
def delete_booking(booking_id):
    cursor = db.cursor()
    try:
        cursor.execute("DELETE FROM bookings WHERE id = %s", (booking_id,))
        db.commit()
        flash("Бронирование отменено.")
    except Exception as e:
        db.rollback()
        app.logger.exception("Error deleting booking")
        flash("Ошибка при удалении брони.")
    finally:
        cursor.close()
    return redirect(url_for("bookings"))


if __name__ == "__main__":
    app.run(debug=True, port=8000)