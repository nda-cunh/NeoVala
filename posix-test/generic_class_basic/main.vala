class Box<G> {
	G val;
	public Box (G v) { this.val = v; }
	public G get () { return this.val; }
}

int main () {
	var a = new Box<int> (42);
	var b = new Box<int> (-7);
	if (a.get () != 42) return 1;
	if (b.get () != -7) return 2;
	return 0;
}
