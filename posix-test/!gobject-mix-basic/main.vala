class PosixClass {
	public int n;
	public PosixClass (int n) { this.n = n; }
	public virtual int weight () { return n; }
}

class PosixChild : PosixClass {
	public PosixChild (int n) { base (n); }
	public override int weight () { return n * 10; }
}

class GobjectClass : GLib.Object {
	public virtual string noise () { return "..."; }
}

class GobjectChild : GobjectClass {
	public override string noise () { return "woof"; }
}

void main () {
	PosixClass p = new PosixChild (4);
	print ("%d\n", p.weight ());

	GobjectClass g = new GobjectChild ();
	print ("%s\n", g.noise ());
	print ("%s\n", (g is GLib.Object).to_string ());
	print ("%s\n", (g is GobjectChild).to_string ());
}
