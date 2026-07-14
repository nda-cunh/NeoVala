interface Stringable { public abstract string to_string (); }
class Point : Stringable {
	public int x; public int y;
	public Point (int x, int y) { this.x = x; this.y = y; }
	public string to_string () { return "(%d,%d)".printf (x, y); }
}
void show<G : Stringable> (G g) { print ("%s\n", g.to_string ()); }
int main () {
	show<int> (7);
	show<Point> (new Point (3, 4));
	show<string> ("mixed");
	return 0;
}
