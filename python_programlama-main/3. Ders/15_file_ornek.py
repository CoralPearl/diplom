# '''
# ADAUSDT parite dosyasını okuma modunda açınız.
# Open, Close, High ve Low değerlerini okuyarak
# ortalamalarını hesaplayıp ekrana yazdırınız.
#
# Arka arkaya en çok kaç saat yükseldiğini ve düştüğünü
#     yazdırınız.
#
# '''
#
# dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
# _open = _close = ysay = dsay = enf_yuk = enf_dus = 0
# for i, satir in enumerate(dosya):
#     if i == 0:
#         continue
#     satir = satir.split(",")
#     _open = float(satir[1])
#     _close = float(satir[4])
#
#     if _open < _close:
#         ysay += 1
#         dsay = 0
#         if enf_yuk < ysay:
#             enf_yuk = ysay
#
#     if _open > _close:
#         dsay += 1
#         ysay = 0
#         if enf_dus < dsay:
#             enf_dus = dsay
#
#     if _open == _close:
#         ysay = dsay = 0
#
#
#
# print("En çok yükseldiği saat sayısı :", enf_yuk)
# print("En çok düştüğü saat sayısı :", enf_dus)
# dosya.close()
#
# '''
#
# 5. saatten itibaren hareketli (5 saatlik) ortalamayı hesaplayınız
#     ve bu değerleri tarih ile birlikte yazdırınız.
# '''
#
# dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
# _close = 0
# degerler = []
# for i, satir in enumerate(dosya):
#     if i == 0:
#         continue
#     satir = satir.split(",")
#     _close = float(satir[4])
#
#     if 0 < i < 6:
#         degerler.append(_close)
#         continue
#
#     ortalama = sum(degerler) / 5
#     print(satir[0], ":", ortalama)
#     degerler.remove(degerler[0])
#     degerler.append(_close)
#
# dosya.close()
#
#
#
# '''
# En yüksek artış ve düşüş gösterdiği günlerin
#     tarih ve yüzdesel değerlerini yazdırınız.
#
# '''
#
# dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
# _close = _open = 0
#
# for i, satir in enumerate(dosya):
#     if i == 0:
#         continue
#     satir = satir.split(",")
#     _close = float(satir[4])
#     _open = float(satir[1])
#
# dosya.close()
# quit()
#
#
#
#
#
#
#
#
#
#
#
#
# dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
# open_ortalama = 0
# for i, satir in enumerate(dosya):
#     if i == 0:
#         continue
#     satir = satir.split(",")
#     open_ortalama += float(satir[1])
# open_ortalama = open_ortalama / 8760
# print("Open Ortalama :", open_ortalama)
#
#
#
#
#
#
#
#
# import pandas as pd
# veri = pd.read_csv("ADAUSDT_mum_1_yil_1_saatlik.csv")
# df = pd.DataFrame(veri, columns=["otime", "open", "high", "low",
#                             "close", "volume"])
# print(df["open"].mean())
# print(df["high"].mean())
# print(df["low"].mean())
# print(df["close"].mean())
# Задача 1: Чтение файла ADAUSDT и расчет среднего, а также подсчет последовательных повышений и понижений

# Открываем файл в режиме чтения
dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")

_open = _close = 0
ysay = dsay = 0  # счетчики для последовательных повышений и понижений
enf_yuk = enf_dus = 0  # максимальные последовательные повышения и понижения

for i, satir in enumerate(dosya):
    if i == 0:  # пропускаем заголовок
        continue
    satir = satir.strip().split(",")
    _open = float(satir[1])
    _close = float(satir[4])

    if _open < _close:
        ysay += 1
        dsay = 0
        if enf_yuk < ysay:
            enf_yuk = ysay
    elif _open > _close:
        dsay += 1
        ysay = 0
        if enf_dus < dsay:
            enf_dus = dsay
    else:
        ysay = dsay = 0

print("Максимальное количество часов роста:", enf_yuk)
print("Максимальное количество часов падения:", enf_dus)

dosya.close()


# Задача 2: Скользящая средняя за 5 часов с выводом даты
dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
degerler = []

for i, satir in enumerate(dosya):
    if i == 0:
        continue
    satir = satir.strip().split(",")
    _close = float(satir[4])

    if 0 < i < 6:
        degerler.append(_close)
        continue

    ortalama = sum(degerler) / 5
    print(satir[0], ":", ortalama)
    degerler.pop(0)
    degerler.append(_close)

dosya.close()


# Задача 3: Вывод дня с наибольшим ростом и падением (в %)
dosya = open("ADAUSDT_mum_1_yil_1_saatlik.csv", "r")
max_increase = max_decrease = 0
date_increase = date_decrease = ""

for i, satir in enumerate(dosya):
    if i == 0:
        continue
    satir = satir.strip().split(",")
    _open = float(satir[1])
    _close = float(satir[4])

    change_percent = ((_close - _open) / _open) * 100

    if change_percent > max_increase:
        max_increase = change_percent
        date_increase = satir[0]

    if change_percent < max_decrease:
        max_decrease = change_percent
        date_decrease = satir[0]

print("День с наибольшим ростом:", date_increase, ":", max_increase, "%")
print("День с наибольшим падением:", date_decrease, ":", max_decrease, "%")

dosya.close()


# Задача 4: Средние значения Open, High, Low, Close за год
import pandas as pd

veri = pd.read_csv("ADAUSDT_mum_1_yil_1_saatlik.csv")
df = pd.DataFrame(veri, columns=["otime", "open", "high", "low", "close", "volume"])

print("Среднее Open:", df["open"].mean())
print("Среднее High:", df["high"].mean())
print("Среднее Low:", df["low"].mean())
print("Среднее Close:", df["close"].mean())