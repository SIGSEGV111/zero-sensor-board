.PHONY: all install clean rebase submodules

all: submodules
	ln -vsnf postgresql /usr/include/pgsql || true
	make -C vz89te-driver vz89te-csv
	make -C sds011-driver sds011-csv
	make -C postgres-feeder

install: all
	./install.sh

clean:
	make -C vz89te-driver clean
	make -C sds011-driver clean
	make -C postgres-feeder clean

submodules:
	git submodule update --init

rebase: submodules
	git -C vz89te-driver fetch
	git -C vz89te-driver checkout master
	git -C vz89te-driver rebase
	git -C sds011-driver fetch
	git -C sds011-driver checkout master
	git -C sds011-driver rebase
	git -C postgres-feeder checkout master
	git -C postgres-feeder fetch
	git -C postgres-feeder rebase

