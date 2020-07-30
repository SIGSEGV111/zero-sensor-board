.PHONY: all install clean

all:
	./compile.sh

install: all
	./install.sh

clean:
	./clean.sh
