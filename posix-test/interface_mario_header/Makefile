run:
	@$(VALAC) main.vala -H mario.h -o main
	@output=$$(valgrind --leak-check=full --error-exitcode=1 ./main 2>&1) || { echo "$$output"; exit 1; }
