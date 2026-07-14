errordomain SimpleError {
	INPUT,
	OUTPUT
}

class Foo {
	public void test (int nb) throws SimpleError.INPUT, SimpleError.OUTPUT {
		if (nb == 0)
			throw new SimpleError.INPUT("Input");
		if (nb < 0)
			throw new SimpleError.OUTPUT("Output");
	}
}

void main() {
	int n = 0;
	try {
		var foo = new Foo();
		foo.test(0);
	}
	catch (SimpleError.INPUT e) {
		n++;
		assert(e.message == "Input");
	}
	catch (SimpleError.OUTPUT e) {
		assert(e.message == "Output");
		n--;
	}
	assert(n == 1);
	try {
		var foo = new Foo();
		foo.test(1);
	}
	catch (SimpleError.INPUT e) {
		assert(e.message == "Input");
		n--;
	}
	catch (SimpleError.OUTPUT e) {
		assert(e.message == "Output");
		n++;
	}
	assert(n == 1);

}
