template class Box<T> {
	public T val;
	public Box (T v) {
		this.val = v;
	}
	public T get () {
		return this.val;
	}
}

void main () {
	var a = new Box<int> (42);
	print ("%d\n", a.get ());
	var b = new Box<int> (7);
	print ("%d\n", b.get ());
}
