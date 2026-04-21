""""Metin trtrttrtr"""

class sinif: #создание класса
    metin = "" #атрибут класса принадлежащий классу
    def __init__(self, a):
        self.metin = a #создаётся атрибут экземпляра metin и записывается значение a

    def __del__(self):

        print("beni siliyorlar...")


nesne = sinif("Mhhhhhetin") #создаём экземпляр класса sinif, передавая строку "Metin" в параметр a.
print(nesne.metin)
del nesne
# Garbage Collector