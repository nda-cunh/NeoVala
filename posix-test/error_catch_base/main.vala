errordomain SimpleError {
	INPUT,
	OUTPUT
}

class Foo {
	public void test (int nb) throws Error {
		if (nb == 0)
			throw new SimpleError.INPUT("Input");
		throw new SimpleError.OUTPUT("Output");
	}
}

void main() {
	int n = 0;

	// general catch of a domain-specific error propagated through `throws Error`
	try {
		new Foo().test(0);
	}
	catch (Error e) {
		assert(e.message == "Input");
		assert(e is Error);
		assert(e is SimpleError);
		assert(e is SimpleError.INPUT);
		n++;
	}
	assert(n == 1);

	// specific clause takes precedence, general clause catches the rest
	for (int i = 0; i < 2; i++) {
		try {
			new Foo().test(i);
		}
		catch (SimpleError.INPUT e) {
			assert(e.message == "Input");
			assert(e.code == SimpleError.INPUT);
			n += 10;
		}
		catch (Error e) {
			assert(e.message == "Output");
			n += 1;
		}
	}
	assert(n == 12);
}
