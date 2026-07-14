interface Stringable { public abstract string to_string (); }
class Pair<A : Stringable, B : Stringable> {
	A first; B second;
	public Pair (owned A a, owned B b) { this.first = (owned) a; this.second = (owned) b; }
	public string show () { return this.first.to_string ().concat (":", this.second.to_string (), null); }
}
int main () {
	var p = new Pair<int, string> (42, "x");
	if (p.show () != "42:x") return 1;
	return 0;
}
