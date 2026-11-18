GLIB_FLAGS := $(addprefix -X ,$(shell pkg-config --cflags --libs glib-2.0))

run:
	@$(VALAC) main.vala -o main $(GLIB_FLAGS)
	@./main
