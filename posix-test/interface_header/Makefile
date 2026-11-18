run:
	@$(VALAC) -H iface.h main.vala Cat.vala Dog.vala IGreeter.vala -o main
	@output=$$(valgrind --leak-check=full --error-exitcode=1 ./main 2>&1) || { echo "$$output"; exit 1; }
