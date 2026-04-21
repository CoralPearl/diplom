"""
iris.data dosyasında yer alan ondalıklı verileri
tam sayıya yuvarlayarak iris_tamsayi.csv dosyasına yazınız.
"""

import csv
veriler = []
baslik = ['sepal_length', 'sepal_width', 'petal_length', 'petal_width', 'species'
5.1,3.5,1.4,0.2,Iris-setosa']

basliklar= None
veriler = []

with open('iris.data', newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        sepal_length = float(row['sepal_length']).__round__()
        sepal_width = float(row['sepal_width']).__round__()
        sepal_width = float(row['sepal_width']).__round__()
        petal_length = float(row['petal_length']).__round__()
        petal_width = float(row['petal_width']).__round__()
        veriler.append([sepal_length, sepal_width, petal_length, petal_width])

        if i == 0:
            basliklar = row.keys()
        veriler.append([round(float(row["sepal_length"])),
                        round(float(row["sepal_width"])),
                        round(float(row["petal_length"])),
                        round(float(row["petal_width"])),
                        row["species"]])

with open('iris_tamsayi.csv',
          'w', encoding='UTF8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(basliklar)
    writer.writerows(veriler)