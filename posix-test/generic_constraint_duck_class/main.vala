interface Stringable { public abstract string to_string (); }
class Holder<G : Stringable> {
	G item;
	public Holder (owned G v) { this.item = (owned) v; }
	public string describe () { return this.item.to_string (); }
}
int main () {
	var h = new Holder<int> (42);
	if (h.describe () != "42") return 1;
	var s = new Holder<string> ("boxed");
	if (s.describe () != "boxed") return 2;
	return 0;
}
