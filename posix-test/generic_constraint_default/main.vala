interface Greet {
	public abstract string name ();
	public virtual string hello () { return "Hi ".concat (this.name (), null); }
}
class Bob : Greet {
	public string name () { return "Bob"; }
}
string greet<G : Greet> (G g) { return g.hello (); }
string who<G : Greet> (G g) { return g.name (); }
int main () {
	if (greet<Bob> (new Bob ()) != "Hi Bob") return 1;
	if (who<Bob> (new Bob ()) != "Bob") return 2;
	return 0;
}
