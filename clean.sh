#!/bin/bash

for m in */Makefile; do
	d="$(dirname "$m")"
	make -C "$d" clean
done
