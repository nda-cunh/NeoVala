// valac main.vala IGreeter.vala Cat.vala Dog.vala

void announce_cat (IGreeter g) {
	assert (g.greet () == "Miaou");
	assert (g.priority () == 28);
}

void announce_dog (IGreeter g) {
	assert (g.greet () == "Woof");
	assert (g.priority () == 7);
}

void main () {
	var d = new Dog ("Rex");
	announce_dog (d);
	var c = new Cat ("Whiskers");
	announce_cat (c);
}
