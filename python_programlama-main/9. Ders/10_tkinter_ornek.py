from tkinter import *

window = Tk()

window.title("Merhaba Python GUI")

# Метки
lbl = Label(window, text="Merhaba")
lbl2 = Label(window, text="Merhaba", font=("Arial Bold", 50))
lbl.grid(column=0, row=0)
lbl2.grid(column=1, row=0)

# Размер окна
window.geometry('500x400')

# Обычная кнопка
btn = Button(window, text="Tıkla")
btn.grid(column=1, row=1)

# -------------------------
# Функция для кнопки tiklandi
# -------------------------
def tiklandi():
    # Меняем текст и цвет
    lbl2.config(text="Tıklandı!", fg="blue")
    window.configure(bg="#f4ede6")   # меняем цвет фона окна для эффекта


# Кнопка с командой
btn2 = Button(window,
              text="Tıkla Renkli",
              bg="orange",
              fg="red",
              width=10,
              height=3,
              command=tiklandi
              )

btn2.grid(column=1, row=3)

# Поля ввода
txt = Entry(window, width=10)
txt.grid(column=0, row=1)

txt2 = Entry(window, width=10, font=("Courier New", 20))
txt2.grid(column=0, row=2)

window.mainloop()