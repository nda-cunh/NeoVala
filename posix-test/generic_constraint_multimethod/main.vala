interface Vec {
	public abstract int x ();
	public abstract int y ();
}
class P : Vec {
	int _x; int _y;
	public P (int x, int y) { _x = x; _y = y; }
	public int x () { return _x; }
	public int y () { return _y; }
}
int sum<G : Vec> (G g) { return g.x () + g.y (); }
int main () {
	if (sum<P> (new P (3, 4)) != 7) return 1;
	return 0;
}
