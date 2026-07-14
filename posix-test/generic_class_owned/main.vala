class Point {
	public int x;
	public Point (int x) { this.x = x; }
}

class Box<G> {
	G val;
	public Box (owned G v) { this.val = (owned) v; }
	public G get () { return this.val; }
}

int main () {
	var bs = new Box<string> ("hello");
	if (bs.get () != "hello") return 1;

	int sum = 0;
	for (int k = 0; k < 5; k++) {
		var bp = new Box<Point> (new Point (k));
		sum += bp.get ().x;
	}
	if (sum != 10) return 2;
	return 0;
}
