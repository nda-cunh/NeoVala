interface Greet {
	public abstract string name ();
	public virtual string hello () { return "Hi ".concat (this.name (), null); }
}
class Bob : Greet {
	public string name () { return "Bob"; }
}
class Al : Greet {
	public string name () { return "Al"; }
}
int main () {
	Greet g = new Bob ();
	if (g.hello () != "Hi Bob") return 1;
	Greet h = new Al ();
	if (h.hello () != "Hi Al") return 2;
	return 0;
}
