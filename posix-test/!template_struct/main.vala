template struct Vec<T> {
	public T x;
	public T y;
	public T sum () {
		return this.x + this.y;
	}
}

void main () {
	Vec<int> a = { 3, 4 };
	print ("%d\n", a.sum ());
	Vec<double> b = { 1.5, 2.5 };
	print ("%g\n", b.sum ());
}
