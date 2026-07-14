interface IShape {
	public abstract int area ();
}
class Square : IShape {
	int side;
	public Square (int s) { this.side = s; }
	public int area () { return this.side * this.side; }
}
class Circle : IShape {
	int r;
	public Circle (int r) { this.r = r; }
	public int area () { return 3 * this.r * this.r; }
}
class Holder<G : IShape> {
	G item;
	public Holder (owned G v) { this.item = (owned) v; }
	public int measure () { return this.item.area (); }
}
int main () {
	var h = new Holder<Square> (new Square (3));
	if (h.measure () != 9) return 1;
	var c = new Holder<Circle> (new Circle (2));
	if (c.measure () != 12) return 2;
	return 0;
}
