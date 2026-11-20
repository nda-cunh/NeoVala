class Foo : Object {
}

class Holder : Object {
	public weak Foo target;
}

void main () {
	var a = new Foo ();
	var b = new Foo ();
	var h = new Holder ();
	h.target = a;
	h.target = b;
	a = null;
	assert (h.target != null);
	b = null;
	assert (h.target == null);
}
