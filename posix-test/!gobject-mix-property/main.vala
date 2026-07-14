class PosixClass {
	public int n { get; set; }
	public string tag { get; set; }
}

class GobjectClass : GLib.Object {
	public int count { get; set; default = 3; }
	public double ratio { get; set; default = 1.5; }
	public bool flag { get; set; default = true; }
	public string label { get; set; default = "hi"; }
	public int64 big { get; set; default = 9000000000; }
}

void main () {
	var p = new PosixClass ();
	p.n = 7;
	p.tag = "posix";
	print ("%s %d\n", p.tag, p.n);

	var g = new GobjectClass ();
	print ("%d %g %s %s %lld\n", g.count, g.ratio, g.flag.to_string (), g.label, g.big);

	g.count = 42;
	g.ratio = 2.5;
	g.flag = false;
	g.label = "changed";
	g.big = -1;
	print ("%d %g %s %s %lld\n", g.count, g.ratio, g.flag.to_string (), g.label, g.big);

	int c;
	g.get ("count", out c);
	print ("get %d\n", c);
	g.set ("count", 99);
	print ("set %d\n", g.count);
}
