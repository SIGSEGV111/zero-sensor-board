.PHONY: all install clean

all:
	make -C vz89te-driver vz89te-csv
	make -C sds011-driver sds011-csv
	make -C postgres-feeder

install: all
	./install.sh

clean:
	make -C vz89te-driver clean
	make -C sds011-driver clean
	make -C postgres-feeder clean
