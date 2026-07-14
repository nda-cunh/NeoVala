delegate int Getter ();

class Counter {
	public int n = 0;
	public int inc () {
		n++;
		return n;
	}
}

class Holder {
	public int factor = 3;
	public int run (Counter c) {
		Getter g = () => {
			return this.factor * c.inc ();
		};
		int total = 0;
		total += g ();
		total += g ();
		return total;
	}
}

void main () {
	var h = new Holder ();
	var c = new Counter ();
	if (h.run (c) != 9)
		Posix.exit (1);
}
