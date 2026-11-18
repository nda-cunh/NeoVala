run:
	@$(VALAC) main.vala -o main
	@valgrind --error-exitcode=1 --leak-check=full ./main
