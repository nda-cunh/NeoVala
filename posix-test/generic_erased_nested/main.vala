namespace Util {
	G id<G> (G a) { return a; }
	G twice<G> (G a) { return id<G> (a); }
}

int main () {
	if (Util.id<int> (5) != 5) return 1;
	if (Util.twice<int> (9) != 9) return 2;
	if (Util.twice<string> ("z") != "z") return 3;
	return 0;
}
