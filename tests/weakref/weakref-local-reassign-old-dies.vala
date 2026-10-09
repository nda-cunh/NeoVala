class Foo : Object {
}

void main () {
	var a = new Foo ();
	var b = new Foo ();
	weakref Foo w = a;
	w = b;
	a = null;
	assert (w != null);
	b = null;
	assert (w == null);
}
