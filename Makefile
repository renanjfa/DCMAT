GCC = gcc
TARGET = parser

LEXICO = lexico.l
SINTATICO = sintatico.y

all:
	flex $(LEXICO)
	bison -d $(SINTATICO)
	$(GCC) *.c -I. -o $(TARGET)

run: all
	./$(TARGET)

clean:
	rm -f $(TARGET)
	rm -f *.c
	rm -f *.h