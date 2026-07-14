errordomain SimpleError {
	INPUT,
	OUTPUT
}

class Foo {
	public void test (int nb) throws SimpleError {
		if (nb == 0)
			throw new SimpleError.INPUT("Input");
		if (nb == 1)
			throw new SimpleError.OUTPUT("Output");
	}
}

void main() {
	var foo = new Foo();
	foo.test(0);

	var foo2 = new Foo();
	print ("NEVER PRINTED\n");
	assert(false);
}
