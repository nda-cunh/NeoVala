delegate int Adder (int x);

Adder make_adder (int base_val) {
	return (x) => {
		return base_val + x;
	};
}

void main () {
	Adder add10 = make_adder (10);
	Adder add100 = make_adder (100);
	if (add10 (5) != 15)
		Posix.exit (1);
	if (add100 (5) != 105)
		Posix.exit (2);
	if (add10 (1) != 11)
		Posix.exit (3);
}
