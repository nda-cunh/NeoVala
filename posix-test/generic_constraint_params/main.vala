interface Scalable {
	public abstract int scaled (int factor);
}
class Box : Scalable {
	int v;
	public Box (int v) { this.v = v; }
	public int scaled (int factor) { return this.v * factor; }
}
int apply<G : Scalable> (G g, int f) {
	return g.scaled (f);
}
int main () {
	if (apply<Box> (new Box (5), 3) != 15) return 1;
	if (apply<Box> (new Box (7), 0) != 0) return 2;
	return 0;
}
