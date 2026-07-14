class Point {
	public int x;
	public Point (int x) { this.x = x; }
}

G id<G> (G a) { return a; }

int main () {
	int sum = 0;
	for (int k = 0; k < 5; k++) {
		var p = new Point (k);
		Point q = id<Point> (p);
		sum += q.x;
	}
	if (sum != 10) return 1;
	return 0;
}
