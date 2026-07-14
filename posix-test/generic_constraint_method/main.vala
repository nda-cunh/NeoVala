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
int total<G : IShape> (G a, G b) {
	return a.area () + b.area ();
}
int main () {
	if (total<Square> (new Square (3), new Square (4)) != 25) return 1;
	if (total<Circle> (new Circle (2), new Circle (1)) != 15) return 2;
	return 0;
}
