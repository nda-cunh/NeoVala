class Pair<A,B> {
	A a; B b;
	public Pair (owned A a, owned B b) { this.a = (owned) a; this.b = (owned) b; }
	public A first () { return this.a; }
	public B second () { return this.b; }
}

int main () {
	var p = new Pair<int,string> (3, "z");
	if (p.first () != 3) return 1;
	if (p.second () != "z") return 2;

	var q = new Pair<string,int> ("y", 9);
	if (q.first () != "y") return 3;
	if (q.second () != 9) return 4;
	return 0;
}
