GCC = gcc
TARGET = slexer

LEXICO = lexico.l

all:
	flex $(LEXICO)
	$(GCC) *.c -I. -o $(TARGET)

run: all
	./$(TARGET)

clean:
	rm -f $(TARGET)
	rm -f *.c
	rm -f *.h