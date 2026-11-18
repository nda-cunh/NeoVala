all: test

test: main.vala
	valac -X -w -X -O3 -X -flto main.vala -o test

run: all
	./test

.PHONY: all test run
