errordomain MyError {
	BAD
}

class Foo {
	public string name;
	public int n;
	public Foo (int n) throws MyError {
		this.name = "prefix-%d".printf (n);
		if (n < 0)
			throw new MyError.BAD ("negatif");
		this.n = n;
	}
}

void main() {
	int hits = 0;
	try {
		var f = new Foo (-1);
		assert (false);
	} catch (MyError e) {
		hits++;
		assert (e.message == "negatif");
	}
	assert (hits == 1);

	try {
		var f = new Foo (5);
		assert (f.n == 5);
		assert (f.name == "prefix-5");
		hits++;
	} catch (MyError e) {
		assert (false);
	}
	assert (hits == 2);
}
