// valac main.vala Dog.vala IGreeter.vala 

int test_id = 0;

void announce (IGreeter g) {
	assert (g.priority() == 7);
	assert (g.greet() == "Woof");
	test_id = 42;
}

void main () {
	var d = new Dog ("Rex");
	announce (d);
	assert (test_id == 42);
}
