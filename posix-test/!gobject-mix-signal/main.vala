class GobjectClass : GLib.Object {
	public signal void spoke (string what);
	public signal void measured (int n, double d);
	public string name { get; set; default = "anon"; }
	public void speak () { spoke ("hello"); }
}

void main () {
	var g = new GobjectClass ();
	g.name = "rex";
	g.spoke.connect ((what) => print ("%s says %s\n", g.name, what));
	g.speak ();

	g.measured.connect ((n, d) => print ("measured %d %g\n", n, d));
	g.measured (5, 0.5);

	g.notify["name"].connect (() => print ("notify\n"));
	g.name = "fido";
}
