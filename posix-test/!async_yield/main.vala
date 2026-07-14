async int inc (int x) {
	return x + 1;
}

async int outer (int x) {
	int a = yield inc (x);
	int b = yield inc (a);
	return b;
}

int result = 0;

void main () {
	outer.begin (10, (s, r) => {
		result = outer.end (r);
	});

	if (result != 12)
		Posix.exit (1);
}
