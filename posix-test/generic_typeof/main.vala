class Point {
	public int x;
	public Point (int x) { this.x = x; }
}

size_t gsize<G> (G a) {
	return sizeof (G);
}

Type gtype<G> (G a) {
	return typeof (G);
}

int main () {
	if (gsize<int> (0) != sizeof (int)) return 1;
	if (gsize<Point> (new Point (1)) != sizeof (Point)) return 2;
	var p = new Point (3);
	if (gtype<Point> (p) != typeof (Point)) return 3;
	if (gtype<int> (0) != typeof (int)) return 4;
	if (typeof (int) == typeof (Point)) return 5;
	if (typeof (int) != typeof (int)) return 6;
	return 0;
}
