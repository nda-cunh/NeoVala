run:
	@$(VALAC) main.vala Shape.vala Rectangle.vala Square.vala -o main
	@output=$$(valgrind --leak-check=full --error-exitcode=1 ./main 2>&1) || { echo "$$output"; exit 1; }
