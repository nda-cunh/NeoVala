delegate int IntOp ();

int apply (IntOp op) {
	return op ();
}

void main () {
	int a = 20;
	int b = 22;
	IntOp add = () => {
		return a + b;
	};
	if (apply (add) != 42)
		Posix.exit (1);

	int counter = 0;
	IntOp bump = () => {
		counter++;
		return counter;
	};
	bump ();
	bump ();
	if (bump () != 3)
		Posix.exit (2);
}
