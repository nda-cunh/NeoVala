GOBJ_FLAGS := $(addprefix -X ,$(shell pkg-config --cflags --libs gobject-2.0))

run:
	@$(VALAC) main.vala -o main $(GOBJ_FLAGS)
	@./main
