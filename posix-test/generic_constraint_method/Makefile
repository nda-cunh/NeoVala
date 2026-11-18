run:
	@$(VALAC) -C main.vala
	@! grep -q "glib-object.h" main.c || { echo "leaked glib-object.h in generated C"; exit 1; }
	@$(VALAC) main.vala -o main
	@valgrind --leak-check=full --error-exitcode=1 ./main >/dev/null 2>&1 || { echo "run/valgrind failed"; exit 1; }
