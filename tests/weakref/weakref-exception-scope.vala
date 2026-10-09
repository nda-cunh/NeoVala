errordomain TestError {
    BOOM
}

int count = 0;

class Foo : Object {
    public string name;

    public Foo (string name) {
        this.name = name;
    }
	~Foo () {
		count++;
	}
}

void may_throw () throws TestError {
    throw new TestError.BOOM ("boom");
}

void main () {
    weakref Foo? w = null;

    try {
        var f = new Foo ("Objet Exception");
        w = f;
        assert (w != null);
		assert (count == 0);

        may_throw ();
    } catch (TestError e) {
		assert (count == 1);
    }

    assert (w == null);
}
