class Abricots {
	public Abricots () { }
	~Abricots () { }
}

class Banane {
	public Banane () { }
}

void main () {
	Type t = typeof (Abricots);

	if (t != typeof (Abricots)) {
		print ("FAIL: typeof(Abricots) not stable\n");
		return;
	}
	if (t == typeof (Banane)) {
		print ("FAIL: distinct classes share a type\n");
		return;
	}

	print ("OK\n");
}
